class MessagesController < ApplicationController
  before_action :require_login
  before_action :set_user

  def index
    @messages = Message.where(user: @user).order(:created_at)
    @message = Message.new
  end

  def create
    @message = Message.new(message_params)
    @message.user = @user
    @message.role = 'user'
    if @message.save
      # Check for ongoing instruction
      if @message.content.strip.downcase.start_with?("ongoing instruction:")
        instruction_text = @message.content.strip.sub(/ongoing instruction:/i, '').strip
        Instruction.create!(user: @user, content: instruction_text)
        Message.create!(user: @user, role: 'assistant', content: "Instruction saved: '#{instruction_text}'")
        flash[:notice] = "Ongoing instruction saved."
        redirect_to messages_path and return
      end
      begin
        # RAG: Retrieve relevant emails
        email_contexts = EmailSearchService.new(@user).search(@message.content)
        context_snippets = email_contexts.map do |email|
          "From: #{email.from}\nSubject: #{email.subject}\nBody: #{email.content.truncate(300)}"
        end.join("\n---\n")

        # Add tool descriptions to the prompt
        tool_descriptions = ToolRegistry.list_descriptions
        system_prompt = <<~PROMPT
          You are Advisor AI, an assistant for financial advisors. You have access to the following tools:
          #{tool_descriptions}

          When you want to use a tool, output ONLY a line in this exact format:
          TOOL: tool_name(param1, param2, ...)

          Only use TOOL: if you are absolutely certain a tool is needed. For normal questions or conversation, just answer naturally and do NOT use TOOL:.

          CRITICAL: Respond ONLY with your answer or tool call. Do NOT include:
          - "User question:" or "Answer:" 
          - Any part of the system prompt
          - Context information
          - Examples or instructions

          Examples of correct responses:
          User: How are you?
          Assistant: I'm doing well, thank you! How can I help you today?

          User: Please email John about our meeting.
          Assistant: TOOL: send_email(John, "Meeting", "Let's meet next week.")

          User: Schedule a meeting with Sara Smith on Friday at 2pm in the office.
          Assistant: TOOL: schedule_meeting(Sara Smith, "Friday", "2pm", "office")

          User: Tell me a joke.
          Assistant: Why did the financial advisor cross the road? To rebalance the chicken's portfolio!
        PROMPT

        # Build context from emails
        context_snippets = ""
        if email_contexts.any?
          context_snippets = "Relevant email context:\n" + email_contexts.map do |email|
            "From: #{email.from}\nSubject: #{email.subject}\nBody: #{email.content.truncate(300)}"
          end.join("\n---\n")
        end

        # Call Ollama API for completion
        client = OpenAI::Client.new(access_token: 'ollama', uri_base: 'http://host.docker.internal:11434/v1')
        response = client.chat(
          parameters: {
            model: "mistral",
            messages: [
              { role: "system", content: system_prompt },
              { role: "user", content: @message.content }
            ]
          }
        )
        ai_reply = response.dig("choices", 0, "message", "content") || "Sorry, I couldn't generate a response."

        # Debug: Log the raw response
        Rails.logger.info("[MessagesController] Raw AI response: #{ai_reply}")

        # Clean up the response - remove any prompt artifacts
        ai_reply = ai_reply.strip
        
        # Remove common prompt artifacts
        ai_reply = ai_reply.gsub(/^User question:.*$/i, '').strip
        ai_reply = ai_reply.gsub(/^Answer:\s*/i, '').strip
        ai_reply = ai_reply.gsub(/^User:.*$/i, '').strip
        ai_reply = ai_reply.gsub(/^Assistant:\s*/i, '').strip
        
        # Remove context if it was included in response
        if context_snippets.present?
          ai_reply = ai_reply.gsub(/Relevant email context:.*$/m, '').strip
        end
        
        # Remove any remaining prompt parts
        ai_reply = ai_reply.gsub(/^You are Advisor AI.*$/m, '').strip
        ai_reply = ai_reply.gsub(/^When you want to use a tool.*$/m, '').strip
        ai_reply = ai_reply.gsub(/^Examples:.*$/m, '').strip
        ai_reply = ai_reply.gsub(/^Important:.*$/m, '').strip
        
        # Clean up multiple newlines
        ai_reply = ai_reply.gsub(/\n{3,}/, "\n\n").strip

        # General tool call parsing: TOOL: tool_name(param1, param2, ...)
        tool_match = ai_reply.match(/^TOOL:\s*(\w+)\((.*)\)$/i)
        if tool_match
          tool_name = tool_match[1]
          param_str = tool_match[2]
          # Split params, handle quoted commas
          params = param_str.scan(/"([^"]*)"|([^,]+)/).map { |m| m[0].presence || m[1].to_s.strip }
          begin
            result = ToolRegistry.call(tool_name, @user, *params)
            Message.create!(user: @user, role: 'assistant', content: result)
          rescue => e
            Rails.logger.error("[MessagesController] tool error: #{e.class} - #{e.message}")
            Message.create!(user: @user, role: 'assistant', content: "Failed to run tool '#{tool_name}': #{e.message}")
          end
        else
          Message.create!(user: @user, role: 'assistant', content: ai_reply)
        end
        flash[:notice] = "Assistant replied successfully."
      rescue Faraday::TooManyRequestsError => e
        Rails.logger.error("[MessagesController] OpenAI API rate limit: #{e.class} - #{e.message}")
        Message.create!(user: @user, role: 'assistant', content: "Sorry, the AI is currently busy due to high demand. Please try again in a few minutes.")
        flash[:alert] = "OpenAI rate limit reached. Please wait a few minutes and try again."
      rescue => e
        Rails.logger.error("[MessagesController] OpenAI API error: #{e.class} - #{e.message}")
        Message.create!(user: @user, role: 'assistant', content: "Sorry, I couldn't generate a response due to an error.")
        flash[:alert] = "There was an error generating the assistant's response."
      end
      redirect_to messages_path
    else
      @messages = Message.where(user: @user).order(:created_at)
      render :index
    end
  end

  private

  def set_user
    @user = current_user
  end

  def message_params
    params.require(:message).permit(:content)
  end
end 
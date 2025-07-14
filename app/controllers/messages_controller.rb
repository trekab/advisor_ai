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
        prompt = <<~PROMPT
          You are Advisor AI, an assistant for financial advisors, inside a web app. You have access to the following tools:
          #{tool_descriptions}

          When you want to use a tool, output a line in this exact format:
          TOOL: tool_name(param1, param2, ...)
          Only use TOOL: if you are absolutely certain a tool is needed. For normal questions or conversation, just answer naturally and do NOT use TOOL:.

          Examples:
          User: How are you?
          Assistant: I'm doing well, thank you! How can I help you today?

          User: Please email John about our meeting.
          Assistant: TOOL: send_email(John, "Meeting", "Let's meet next week.")

          User: Schedule a meeting with Sara Smith on Friday at 2pm in the office.
          Assistant: TOOL: schedule_meeting(Sara Smith, "Friday", "2pm", "office")

          User: Tell me a joke.
          Assistant: Why did the financial advisor cross the road? To rebalance the chicken's portfolio!

          Context:
          #{context_snippets}

          User question: #{@message.content}

          Answer:
        PROMPT

        # Call Ollama API for completion
        client = OpenAI::Client.new(access_token: 'ollama', uri_base: 'http://host.docker.internal:11434/v1')
        response = client.chat(
          parameters: {
            model: "mistral",
            messages: [
              { role: "system", content: "You are an AI assistant for a financial advisor." },
              { role: "user", content: prompt }
            ]
          }
        )
        ai_reply = response.dig("choices", 0, "message", "content") || "Sorry, I couldn't generate a response."

        # General tool call parsing: TOOL: tool_name(param1, param2, ...)
        tool_match = ai_reply.match(/^TOOL: (\w+)\((.*)\)$/m)
        if tool_match
          tool_name = tool_match[1]
          param_str = tool_match[2]
          # Split params, handle quoted commas
          params = param_str.scan(/"([^"]*)"|([^,]+)/).map { |m| m[0].presence || m[1].to_s.strip }
          begin
            # Set @user context for tool execution
            ToolRegistry.class_eval { @user = @user }
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
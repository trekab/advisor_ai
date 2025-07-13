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
      begin
        # RAG: Retrieve relevant emails
        email_contexts = EmailSearchService.new(@user).search(@message.content)
        context_snippets = email_contexts.map do |email|
          "From: #{email.from}\nSubject: #{email.subject}\nBody: #{email.content.truncate(300)}"
        end.join("\n---\n")

        # Assemble prompt
        prompt = <<~PROMPT
          You are an AI assistant for a financial advisor. Use the following email context to answer the user's question. If you want to send an email, output a line in this exact format:
          TOOL: send_email(to, subject, body)
          Otherwise, just answer the question as usual.
          
          Context:
          #{context_snippets}
          
          User question: #{@message.content}
          
          Answer:
        PROMPT

        # Call OpenAI API for completion
        client = OpenAI::Client.new(access_token: ENV['OPENAI_API_KEY'])
        response = client.chat(
          parameters: {
            model: "gpt-3.5-turbo",
            messages: [
              { role: "system", content: "You are an AI assistant for a financial advisor." },
              { role: "user", content: prompt }
            ]
          }
        )
        ai_reply = response.dig("choices", 0, "message", "content") || "Sorry, I couldn't generate a response."

        # Check for tool call
        tool_match = ai_reply.match(/^TOOL: send_email\(([^,]+),\s*([^,]+),\s*(.+)\)$/m)
        if tool_match
          to = tool_match[1].strip
          subject = tool_match[2].strip
          body = tool_match[3].strip
          begin
            GmailClient.new(@user).send_email(to: to, subject: subject, body: body)
            Message.create!(user: @user, role: 'assistant', content: "Email sent to #{to} with subject '#{subject}'.")
          rescue => e
            Rails.logger.error("[MessagesController] send_email tool error: #{e.class} - #{e.message}")
            Message.create!(user: @user, role: 'assistant', content: "Failed to send email: #{e.message}")
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
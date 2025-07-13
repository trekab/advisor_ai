class MessagesController < ApplicationController
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
          You are an AI assistant for a financial advisor. Use the following email context to answer the user's question. If the context is not helpful, answer as best you can.
          
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
        Message.create!(user: @user, role: 'assistant', content: ai_reply)
        flash[:notice] = "Assistant replied successfully."
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
    # For now, use the first user (replace with real auth logic)
    @user = User.first
  end

  def message_params
    params.require(:message).permit(:content)
  end
end 
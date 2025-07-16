class MessagesController < ApplicationController
  before_action :require_login
  before_action :set_user

  def index
    @messages = @user.messages.order(created_at: :asc)
    @message = Message.new
  end

  def create
    @message = @user.messages.build(message_params)
    @message.role = 'user'
    
    if @message.save
      # Process with AI using RAG and tool calling
      ai_response = process_with_ai(@message.content)
      
      # Save AI response
      @user.messages.create!(
        role: 'assistant',
        content: ai_response
      )
      
      if request.xhr?
        # Return success for AJAX requests
        render json: { success: true }
      else
        redirect_to messages_path
      end
    else
      if request.xhr?
        render json: { success: false, errors: @message.errors.full_messages }
      else
        @messages = @user.messages.order(created_at: :asc)
        render :index
      end
    end
  end

  private

  def set_user
    @user = current_user
  end

  def message_params
    params.require(:message).permit(:content)
  end

  def process_with_ai(user_message)
    # Get relevant context using RAG
    context = get_relevant_context(user_message)
    
    # Build system prompt with tools and context
    system_prompt = build_system_prompt(context)
    
    # Get AI response with tool calling capability
    response = get_ai_response(system_prompt, user_message)
    
    # Execute any tool calls
    final_response = execute_tool_calls(response, user_message)
    
    final_response
  end

  def get_relevant_context(query)
    embedding_service = EmbeddingService.new
    
    # Search emails
    relevant_emails = embedding_service.search_emails(query, @user.id, limit: 3)
    
    # Search HubSpot contacts
    relevant_contacts = embedding_service.search_hubspot_data(query, @user.id, limit: 3)
    
    context = []
    
    if relevant_emails.any?
      context << "Relevant emails:\n" + relevant_emails.map do |email|
        "From: #{email.from}\nSubject: #{email.subject}\nContent: #{email.content&.truncate(300)}"
      end.join("\n\n")
    end
    
    if relevant_contacts.any?
      context << "Relevant contacts:\n" + relevant_contacts.map do |contact|
        "Name: #{contact[:first_name]} #{contact[:last_name]}\nEmail: #{contact[:email]}\nCompany: #{contact[:company]}"
      end.join("\n\n")
    end
    
    context.join("\n\n")
  end

  def build_system_prompt(context)
    tool_registry = ToolRegistry.new(@user)
    tools = tool_registry.available_tools
    
    tools_description = tools.map do |name, tool|
      params = tool[:parameters].map { |k, v| "#{k}: #{v[:type]}" }.join(", ")
      "- #{name}(#{params}): #{tool[:description]}"
    end.join("\n")
    
    <<~PROMPT
      You are an AI assistant for a financial advisor. You have access to the user's emails, calendar, and HubSpot CRM.
      
      Available tools:
      #{tools_description}
      
      When you need to perform actions, use the tool calling format:
      TOOL_CALL: tool_name
      PARAMETERS: {"param1": "value1", "param2": "value2"}
      
      Context from user's data:
      #{context}
      
      Instructions:
      1. Use the available tools to help the user
      2. Search emails and contacts when relevant
      3. Be proactive and helpful
      4. For complex tasks, create tasks to track progress
      5. Always provide clear, actionable responses
    PROMPT
  end

  def get_ai_response(system_prompt, user_message)
    client = OpenAI::Client.new(access_token: 'ollama', uri_base: 'http://host.docker.internal:11434/v1')
    
    response = client.chat(
      parameters: {
        model: "mistral",
        messages: [
          { role: "system", content: system_prompt },
          { role: "user", content: user_message }
        ]
      }
    )
    
    response.dig("choices", 0, "message", "content") || "Sorry, I couldn't generate a response."
  rescue => e
    Rails.logger.error("AI response error: #{e.message}")
    "I apologize, but I'm having trouble processing your request right now. Please try again."
  end

  def execute_tool_calls(response, original_message)
    # Simple tool calling parser - in production you'd use a more sophisticated approach
    if response.include?('TOOL_CALL:')
      lines = response.split("\n")
      tool_calls = []
      
      lines.each_with_index do |line, index|
        if line.start_with?('TOOL_CALL:')
          tool_name = line.split(': ').last.strip
          params_line = lines[index + 1]
          
          if params_line&.start_with?('PARAMETERS:')
            params_json = params_line.split(': ').last.strip
            begin
              params = JSON.parse(params_json)
              tool_calls << { tool: tool_name, parameters: params }
            rescue JSON::ParserError
              Rails.logger.error("Invalid tool parameters: #{params_json}")
            end
          end
        end
      end
      
      # Execute tool calls
      tool_registry = ToolRegistry.new(@user)
      results = []
      
      tool_calls.each do |tool_call|
        result = tool_registry.execute_tool(tool_call[:tool], tool_call[:parameters])
        results << "Tool #{tool_call[:tool]} result: #{result}"
      end
      
      # Generate final response with tool results
      if results.any?
        final_prompt = "Original user message: #{original_message}\n\nTool execution results:\n#{results.join("\n")}\n\nProvide a helpful response to the user based on these results."
        
        client = OpenAI::Client.new(access_token: 'ollama', uri_base: 'http://host.docker.internal:11434/v1')
        final_response = client.chat(
          parameters: {
            model: "mistral",
            messages: [
              { role: "system", content: "You are a helpful AI assistant. Provide clear, actionable responses based on the tool execution results." },
              { role: "user", content: final_prompt }
            ]
          }
        )
        
        final_response.dig("choices", 0, "message", "content") || "Sorry, I couldn't generate a response."
      else
        response
      end
    else
      response
    end
  end
end 
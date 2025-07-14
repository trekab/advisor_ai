class ToolRegistry
  def initialize(user)
    @user = user
    @embedding_service = EmbeddingService.new
  end

  def available_tools
    {
      search_emails: {
        description: "Search through user's emails using semantic search",
        parameters: {
          query: { type: "string", description: "Search query" },
          limit: { type: "integer", description: "Number of results", default: 5 }
        }
      },
      search_contacts: {
        description: "Search through HubSpot contacts",
        parameters: {
          query: { type: "string", description: "Search query" },
          limit: { type: "integer", description: "Number of results", default: 5 }
        }
      },
      send_email: {
        description: "Send an email to a recipient",
        parameters: {
          to: { type: "string", description: "Recipient email address" },
          subject: { type: "string", description: "Email subject" },
          body: { type: "string", description: "Email body" }
        }
      },
      schedule_meeting: {
        description: "Schedule a meeting in Google Calendar",
        parameters: {
          summary: { type: "string", description: "Meeting title" },
          start_time: { type: "string", description: "Start time (ISO 8601)" },
          end_time: { type: "string", description: "End time (ISO 8601)" },
          attendees: { type: "array", description: "List of attendee emails" },
          description: { type: "string", description: "Meeting description" }
        }
      },
      find_available_slots: {
        description: "Find available time slots in calendar",
        parameters: {
          date: { type: "string", description: "Date to check (YYYY-MM-DD)" },
          duration_minutes: { type: "integer", description: "Duration in minutes", default: 60 }
        }
      },
      create_hubspot_contact: {
        description: "Create a new contact in HubSpot",
        parameters: {
          first_name: { type: "string", description: "First name" },
          last_name: { type: "string", description: "Last name" },
          email: { type: "string", description: "Email address" },
          company: { type: "string", description: "Company name" },
          notes: { type: "string", description: "Contact notes" }
        }
      },
      add_hubspot_note: {
        description: "Add a note to a HubSpot contact",
        parameters: {
          contact_email: { type: "string", description: "Contact email" },
          note: { type: "string", description: "Note content" }
        }
      },
      create_task: {
        description: "Create a new task to track multi-step operations",
        parameters: {
          title: { type: "string", description: "Task title" },
          description: { type: "string", description: "Task description" },
          task_type: { type: "string", description: "Type of task" }
        }
      },
      update_task: {
        description: "Update an existing task",
        parameters: {
          task_id: { type: "integer", description: "Task ID" },
          status: { type: "string", description: "New status" },
          progress: { type: "string", description: "Progress update" }
        }
      }
    }
  end

  def execute_tool(tool_name, parameters)
    case tool_name.to_sym
    when :search_emails
      search_emails(parameters[:query], parameters[:limit] || 5)
    when :search_contacts
      search_contacts(parameters[:query], parameters[:limit] || 5)
    when :send_email
      send_email(parameters[:to], parameters[:subject], parameters[:body])
    when :schedule_meeting
      schedule_meeting(parameters)
    when :find_available_slots
      find_available_slots(parameters[:date], parameters[:duration_minutes] || 60)
    when :create_hubspot_contact
      create_hubspot_contact(parameters)
    when :add_hubspot_note
      add_hubspot_note(parameters[:contact_email], parameters[:note])
    when :create_task
      create_task(parameters)
    when :update_task
      update_task(parameters)
    else
      { error: "Unknown tool: #{tool_name}" }
    end
  rescue => e
    { error: e.message }
  end

  private

  def search_emails(query, limit)
    emails = @embedding_service.search_emails(query, @user.id, limit: limit)
    {
      results: emails.map do |email|
        {
          id: email.id,
          subject: email.subject,
          from: email.from,
          content: email.content&.truncate(200),
          date: email.created_at
        }
      end
    }
  end

  def search_contacts(query, limit)
    contacts = @embedding_service.search_hubspot_data(query, @user.id, limit: limit)
    {
      results: contacts.map do |contact|
        {
          id: contact[:id],
          name: "#{contact[:first_name]} #{contact[:last_name]}",
          email: contact[:email],
          company: contact[:company]
        }
      end
    }
  end

  def send_email(to, subject, body)
    # Use Gmail API to send email
    gmail_client = GmailClient.new(@user)
    result = gmail_client.send_email(to: to, subject: subject, body: body)
    
    if result[:success]
      { success: true, message_id: result[:message_id] }
    else
      { error: result[:error] }
    end
  end

  def schedule_meeting(parameters)
    calendar_client = GoogleCalendarClient.new(@user)
    result = calendar_client.create_event(
      summary: parameters[:summary],
      description: parameters[:description],
      start_time: Time.parse(parameters[:start_time]),
      end_time: Time.parse(parameters[:end_time]),
      attendees: parameters[:attendees] || [],
      location: parameters[:location]
    )
    
    { success: true, event_id: result[:id] }
  end

  def find_available_slots(date, duration_minutes)
    calendar_client = GoogleCalendarClient.new(@user)
    slots = calendar_client.find_available_slots(
      date: Date.parse(date),
      duration_minutes: duration_minutes
    )
    
    {
      slots: slots.map do |slot|
        {
          start_time: slot[:start_time].iso8601,
          end_time: slot[:end_time].iso8601
        }
      end
    }
  end

  def create_hubspot_contact(parameters)
    hubspot_client = HubspotClient.new(@user)
    result = hubspot_client.create_contact(
      first_name: parameters[:first_name],
      last_name: parameters[:last_name],
      email: parameters[:email],
      company: parameters[:company]
    )
    
    if result[:success]
      hubspot_client.add_note(result[:contact_id], parameters[:notes]) if parameters[:notes].present?
      { success: true, contact_id: result[:contact_id] }
    else
      { error: result[:error] }
    end
  end

  def add_hubspot_note(contact_email, note)
    hubspot_client = HubspotClient.new(@user)
    contact = hubspot_client.find_contact_by_email(contact_email)
    
    if contact
      result = hubspot_client.add_note(contact[:id], note)
      { success: true, note_id: result[:note_id] }
    else
      { error: "Contact not found" }
    end
  end

  def create_task(parameters)
    task = @user.tasks.create!(
      title: parameters[:title],
      description: parameters[:description],
      task_type: parameters[:task_type] || 'general',
      status: 'pending'
    )
    
    { success: true, task_id: task.id }
  end

  def update_task(parameters)
    task = @user.tasks.find(parameters[:task_id])
    task.update_progress(parameters[:progress]) if parameters[:progress]
    task.status = parameters[:status] if parameters[:status]
    task.save!
    
    { success: true, task_id: task.id }
  end
end 
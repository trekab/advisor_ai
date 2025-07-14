class ToolRegistry
  Tool = Struct.new(:name, :description, :parameters, :executor)

  def self.tools
    @tools ||= {}
  end

  def self.register(name, description:, parameters:, &block)
    tools[name.to_s] = Tool.new(name.to_s, description, parameters, block)
  end

  def self.find(name)
    tools[name.to_s]
  end

  def self.list_descriptions
    tools.values.map do |tool|
      "- #{tool.name}(#{tool.parameters.join(', ')}): #{tool.description}"
    end.join("\n")
  end

  def self.call(name, user, *args)
    tool = find(name)
    raise "Tool not found: #{name}" unless tool
    tool.executor.call(user, *args)
  end
end

# Register send_email tool
ToolRegistry.register(
  :send_email,
  description: "Send an email to a recipient with a subject and body.",
  parameters: ["to", "subject", "body"]
) do |user, to, subject, body|
  raise "User must be present for send_email" unless user
  GmailClient.new(user).send_email(to: to, subject: subject, body: body)
  "Email sent to #{to} with subject '#{subject}'."
end

# Register schedule_meeting tool
ToolRegistry.register(
  :schedule_meeting,
  description: "Schedule a meeting with a contact. Parameters: with (person), date, time, location.",
  parameters: ["with", "date", "time", "location"]
) do |user, with, date, time, location|
  raise "User must be present for schedule_meeting" unless user
  
  # Parse date and time
  begin
    # Try to parse the date and time
    parsed_date = Date.parse(date)
    parsed_time = Time.parse(time)
    
    # Combine date and time
    start_time = parsed_date.to_time.change(hour: parsed_time.hour, min: parsed_time.min)
    end_time = start_time + 1.hour # Default 1-hour meeting
    
    # Create calendar event
    calendar = GoogleCalendarClient.new(user)
    event = calendar.create_event(
      summary: "Meeting with #{with}",
      description: "Meeting scheduled via Advisor AI",
      start_time: start_time,
      end_time: end_time,
      location: location
    )
    
    "Meeting scheduled with #{with} on #{parsed_date.strftime('%B %d, %Y')} at #{parsed_time.strftime('%I:%M %p')} in #{location}. Calendar event created successfully."
  rescue Date::Error, ArgumentError => e
    "Failed to parse date/time: #{date} at #{time}. Please use a clear format like 'Monday' or '2024-01-15' for date and '2:30 PM' for time."
  rescue => e
    "Failed to schedule meeting: #{e.message}"
  end
end

# Register create_contact tool
ToolRegistry.register(
  :create_contact,
  description: "Create a new contact in the CRM. Parameters: name, email, notes.",
  parameters: ["name", "email", "notes"]
) do |user, name, email, notes|
  raise "User must be present for create_contact" unless user
  HubspotClient.new(user).create_contact(name: name, email: email, notes: notes)
end

# Register add_contact_note tool
ToolRegistry.register(
  :add_contact_note,
  description: "Add a note to a contact in the CRM. Parameters: contact_email, note.",
  parameters: ["contact_email", "note"]
) do |user, contact_email, note|
  raise "User must be present for add_contact_note" unless user
  HubspotClient.new(user).add_contact_note(contact_email: contact_email, note: note)
end

# Register list_calendar_events tool
ToolRegistry.register(
  :list_calendar_events,
  description: "List upcoming calendar events. Parameters: days (optional, default 7).",
  parameters: ["days"]
) do |user, days = "7"|
  raise "User must be present for list_calendar_events" unless user
  
  begin
    days_count = days.to_i
    time_max = days_count.days.from_now.end_of_day
    
    calendar = GoogleCalendarClient.new(user)
    events = calendar.list_events(time_max: time_max)
    
    if events.empty?
      "No upcoming events in the next #{days_count} days."
    else
      event_list = events.map do |event|
        start_time = Time.parse(event[:start_time])
        "- #{event[:summary]} on #{start_time.strftime('%B %d at %I:%M %p')}"
      end.join("\n")
      
      "Upcoming events in the next #{days_count} days:\n#{event_list}"
    end
  rescue => e
    "Failed to list calendar events: #{e.message}"
  end
end

# Register find_available_slots tool
ToolRegistry.register(
  :find_available_slots,
  description: "Find available time slots for a meeting. Parameters: date, duration_minutes (optional, default 60).",
  parameters: ["date", "duration_minutes"]
) do |user, date, duration_minutes = "60"|
  raise "User must be present for find_available_slots" unless user
  
  begin
    parsed_date = Date.parse(date)
    duration = duration_minutes.to_i
    
    calendar = GoogleCalendarClient.new(user)
    slots = calendar.find_available_slots(date: parsed_date, duration_minutes: duration)
    
    if slots.empty?
      "No available #{duration}-minute slots on #{parsed_date.strftime('%B %d, %Y')}."
    else
      slot_list = slots.first(5).map do |slot|
        "- #{slot[:start_time].strftime('%I:%M %p')} to #{slot[:end_time].strftime('%I:%M %p')}"
      end.join("\n")
      
      "Available #{duration}-minute slots on #{parsed_date.strftime('%B %d, %Y')}:\n#{slot_list}"
    end
  rescue Date::Error => e
    "Failed to parse date: #{date}. Please use a clear format like 'Monday' or '2024-01-15'."
  rescue => e
    "Failed to find available slots: #{e.message}"
  end
end

# Register search_contacts tool
ToolRegistry.register(
  :search_contacts,
  description: "Search for contacts in HubSpot CRM. Parameters: query (email or name).",
  parameters: ["query"]
) do |user, query|
  raise "User must be present for search_contacts" unless user
  
  begin
    hubspot = HubspotClient.new(user)
    contacts = hubspot.search_contacts(query)
    
    if contacts.empty?
      "No contacts found matching '#{query}'."
    else
      contact_list = contacts.map do |contact|
        name = [contact[:first_name], contact[:last_name]].compact.join(' ')
        company = contact[:company].present? ? " (#{contact[:company]})" : ""
        "- #{name}#{company} - #{contact[:email]}"
      end.join("\n")
      
      "Found #{contacts.count} contact(s) matching '#{query}':\n#{contact_list}"
    end
  rescue => e
    "Failed to search contacts: #{e.message}"
  end
end

# Register create_deal tool
ToolRegistry.register(
  :create_deal,
  description: "Create a new deal in HubSpot CRM. Parameters: name, amount, contact_email (optional).",
  parameters: ["name", "amount", "contact_email"]
) do |user, name, amount, contact_email = nil|
  raise "User must be present for create_deal" unless user
  
  begin
    hubspot = HubspotClient.new(user)
    result = hubspot.create_deal(name: name, amount: amount, contact_email: contact_email)
    result
  rescue => e
    "Failed to create deal: #{e.message}"
  end
end 
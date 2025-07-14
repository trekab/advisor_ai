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
  "Meeting scheduled with #{with} on #{date} at #{time} in #{location}."
end

# Register create_contact tool
ToolRegistry.register(
  :create_contact,
  description: "Create a new contact in the CRM. Parameters: name, email, notes.",
  parameters: ["name", "email", "notes"]
) do |user, name, email, notes|
  "Contact '#{name}' (#{email}) created with notes: #{notes}."
end

# Register add_contact_note tool
ToolRegistry.register(
  :add_contact_note,
  description: "Add a note to a contact in the CRM. Parameters: contact_email, note.",
  parameters: ["contact_email", "note"]
) do |user, contact_email, note|
  "Note added to contact #{contact_email}: #{note}."
end 
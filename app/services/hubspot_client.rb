require 'hubspot-api-client'

class HubspotClient
  def initialize(user)
    @user = user
    @client = Hubspot::Client.new(access_token: user.hubspot_access_token)
  end

  def create_contact(name:, email:, notes:)
    begin
      properties = {
        firstname: name.split(' ').first,
        lastname: name.split(' ').last || '',
        email: email
      }
      
      properties[:notes] = notes if notes.present?
      
      response = @client.crm.contacts.basic_api.create(
        public_object_input: {
          properties: properties
        }
      )
      
      "Contact created successfully: #{name} (#{email})"
    rescue => e
      "Failed to create contact: #{e.message}"
    end
  end

  def add_contact_note(contact_email:, note:)
    begin
      # First, find the contact by email
      filter = { propertyName: 'email', operator: 'EQ', value: contact_email }
      response = @client.crm.contacts.search_api.do_search(
        public_object_search_request: {
          filter_groups: [{ filters: [filter] }]
        }
      )
      
      if response.results.empty?
        return "Contact not found with email: #{contact_email}"
      end
      
      contact_id = response.results.first.id
      
      # Create a note
      note_properties = {
        hs_note_body: note,
        hs_timestamp: Time.current.to_i * 1000 # HubSpot expects milliseconds
      }
      
      @client.crm.objects.notes.basic_api.create(
        simple_public_object_input: {
          properties: note_properties,
          associations: [
            {
              to: { id: contact_id },
              types: [{ association_category: 'HUBSPOT_DEFINED', association_type_id: 1 }]
            }
          ]
        }
      )
      
      "Note added successfully to contact: #{contact_email}"
    rescue => e
      "Failed to add note: #{e.message}"
    end
  end

  def connected?
    @user.hubspot_access_token.present?
  end
end 
require 'hubspot-api-client'

class HubspotClient
  def initialize(user)
    @user = user
    @client = build_client
  end

  private

  def build_client
    access_token = get_valid_access_token
    Hubspot::Client.new(access_token: access_token)
  end

  def get_valid_access_token
    return @user.hubspot_access_token unless token_expired?
    
    Rails.logger.info("[HubspotClient] Refreshing expired token for User##{@user.id}")
    
    begin
      oauth_client = HubspotOauthClient.new
      token_response = oauth_client.refresh_token(@user.hubspot_refresh_token)
      
      @user.update!(
        hubspot_access_token: token_response['access_token'],
        hubspot_refresh_token: token_response['refresh_token']
      )
      
      token_response['access_token']
    rescue => e
      Rails.logger.error("[HubspotClient] Failed to refresh token for User##{@user.id}: #{e.message}")
      raise "HubSpot authentication failed. Please reconnect your account."
    end
  end

  def token_expired?
    return true unless @user.hubspot_access_token.present?
    
    # HubSpot tokens typically expire in 6 hours, but we'll refresh if older than 5 hours
    @user.hubspot_token_updated_at.nil? || @user.hubspot_token_updated_at < 5.hours.ago
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

  def search_contacts(query)
    begin
      filter = { propertyName: 'email', operator: 'CONTAINS_TOKEN', value: query }
      response = @client.crm.contacts.search_api.do_search(
        public_object_search_request: {
          filter_groups: [{ filters: [filter] }],
          limit: 10
        }
      )
      
      response.results.map do |contact|
        {
          id: contact.id,
          email: contact.properties['email'],
          first_name: contact.properties['firstname'],
          last_name: contact.properties['lastname'],
          company: contact.properties['company']
        }
      end
    rescue => e
      Rails.logger.error("[HubspotClient] Search contacts error: #{e.message}")
      []
    end
  end

  def create_deal(name:, amount:, contact_email: nil)
    begin
      properties = {
        dealname: name,
        amount: amount.to_s
      }
      
      deal_response = @client.crm.deals.basic_api.create(
        simple_public_object_input: {
          properties: properties
        }
      )
      
      # If contact email provided, associate the deal with the contact
      if contact_email.present?
        contact = search_contacts(contact_email).first
        if contact
          @client.crm.deals.associations_api.create(
            deal_id: deal_response.id,
            to_object_type: 'contacts',
            to_object_id: contact[:id],
            association_type: 'deal_to_contact'
          )
        end
      end
      
      "Deal created successfully: #{name} ($#{amount})"
    rescue => e
      "Failed to create deal: #{e.message}"
    end
  end

  def connected?
    @user.hubspot_access_token.present?
  end
end 
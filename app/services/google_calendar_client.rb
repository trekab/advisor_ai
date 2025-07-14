require 'google/apis/calendar_v3'
require 'googleauth'
require 'signet/oauth_2/client'

class GoogleCalendarClient
  def initialize(user)
    @user = user
    @service = Google::Apis::CalendarV3::CalendarService.new
    @service.authorization = build_authorizer
  end

  def create_event(summary:, description: nil, start_time:, end_time:, attendees: [], location: nil)
    event = Google::Apis::CalendarV3::Event.new(
      summary: summary,
      description: description,
      start: {
        date_time: start_time.iso8601,
        time_zone: 'UTC'
      },
      end: {
        date_time: end_time.iso8601,
        time_zone: 'UTC'
      },
      attendees: attendees.map { |email| { email: email } },
      location: location
    )

    result = @service.insert_event('primary', event)
    {
      id: result.id,
      summary: result.summary,
      start_time: result.start.date_time,
      end_time: result.end.date_time,
      attendees: result.attendees&.map(&:email) || [],
      location: result.location
    }
  rescue Google::Apis::AuthorizationError => e
    Rails.logger.error("[GoogleCalendarClient] Auth error for user #{@user.id}: #{e.message}")
    raise "Calendar access not authorized. Please reconnect your Google account."
  rescue => e
    Rails.logger.error("[GoogleCalendarClient] Error creating event: #{e.class} - #{e.message}")
    raise "Failed to create calendar event: #{e.message}"
  end

  def list_events(max_results: 10, time_min: nil, time_max: nil)
    time_min ||= Time.current.beginning_of_day
    time_max ||= 1.month.from_now.end_of_day

    result = @service.list_events(
      'primary',
      max_results: max_results,
      time_min: time_min.iso8601,
      time_max: time_max.iso8601,
      single_events: true,
      order_by: 'startTime'
    )

    result.items.map do |event|
      {
        id: event.id,
        summary: event.summary,
        description: event.description,
        start_time: event.start.date_time,
        end_time: event.end.date_time,
        attendees: event.attendees&.map(&:email) || [],
        location: event.location
      }
    end
  rescue Google::Apis::AuthorizationError => e
    Rails.logger.error("[GoogleCalendarClient] Auth error for user #{@user.id}: #{e.message}")
    []
  rescue => e
    Rails.logger.error("[GoogleCalendarClient] Error listing events: #{e.class} - #{e.message}")
    []
  end

  def find_available_slots(date:, duration_minutes: 60, business_hours: { start: 9, end: 17 })
    # Get existing events for the date
    start_of_day = date.beginning_of_day
    end_of_day = date.end_of_day
    
    existing_events = list_events(time_min: start_of_day, time_max: end_of_day)
    
    # Create time slots
    slots = []
    current_time = start_of_day.change(hour: business_hours[:start])
    end_time = start_of_day.change(hour: business_hours[:end])
    
    while current_time + duration_minutes.minutes <= end_time
      slot_end = current_time + duration_minutes.minutes
      
      # Check if slot conflicts with existing events
      conflicting = existing_events.any? do |event|
        event_start = Time.parse(event[:start_time])
        event_end = Time.parse(event[:end_time])
        
        (current_time < event_end) && (slot_end > event_start)
      end
      
      unless conflicting
        slots << {
          start_time: current_time,
          end_time: slot_end
        }
      end
      
      current_time += 30.minutes # 30-minute intervals
    end
    
    slots
  end

  private

  def build_authorizer
    Rails.logger.info("[GoogleCalendarClient] Building authorizer for User##{@user.id}")
    
    client = Signet::OAuth2::Client.new(
      client_id: ENV['GOOGLE_CLIENT_ID'],
      client_secret: ENV['GOOGLE_CLIENT_SECRET'],
      token_credential_uri: 'https://oauth2.googleapis.com/token',
      access_token: @user.google_access_token,
      refresh_token: @user.google_refresh_token
    )
    
    begin
      client.fetch_access_token!
      Rails.logger.info("[GoogleCalendarClient] Successfully refreshed access token for User##{@user.id}")
      client
    rescue => e
      Rails.logger.error("[GoogleCalendarClient] Failed to refresh access token for User##{@user.id}: #{e.class} - #{e.message}")
      raise "Failed to authenticate with Google Calendar: #{e.message}"
    end
  end
end 
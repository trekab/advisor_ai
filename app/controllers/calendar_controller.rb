class CalendarController < ApplicationController
  before_action :require_login
  before_action :set_user

  def index
    @events = []
    @available_slots = []
    
    if @user.google_access_token.present?
      begin
        calendar = GoogleCalendarClient.new(@user)
        @events = calendar.list_events(max_results: 20)
        
        # Get available slots for today
        @available_slots = calendar.find_available_slots(date: Date.current)
      rescue => e
        flash[:alert] = "Unable to load calendar: #{e.message}"
      end
    else
      flash[:alert] = "Please connect your Google account to view calendar events."
    end
  end

  def sync
    if @user.google_access_token.present?
      CalendarSyncJob.perform_later(@user.id)
      flash[:notice] = "Calendar sync started. This may take a few minutes."
    else
      flash[:alert] = "Please connect your Google account first."
    end
    
    redirect_to calendar_index_path
  end

  private

  def set_user
    @user = current_user
  end
end 
#!/usr/bin/env ruby

# Test script for Google Calendar integration
# Run with: docker compose run web ruby test_calendar.rb

require_relative 'config/environment'

puts "Testing Google Calendar Integration..."
puts "====================================="

# Find a user with Google access
user = User.where.not(google_access_token: nil).first

if user.nil?
  puts "❌ No users found with Google access tokens"
  puts "Please connect a Google account first by visiting the app"
  exit 1
end

puts "✅ Found user: #{user.email}"

begin
  # Test calendar client initialization
  puts "\n🔧 Testing calendar client initialization..."
  calendar = GoogleCalendarClient.new(user)
  puts "✅ Calendar client initialized successfully"
  
  # Test listing events
  puts "\n📅 Testing event listing..."
  events = calendar.list_events(max_results: 5)
  puts "✅ Found #{events.count} events"
  
  if events.any?
    puts "\n📋 Recent events:"
    events.each do |event|
      puts "  - #{event[:summary]} (#{event[:start_time]})"
    end
  end
  
  # Test finding available slots
  puts "\n⏰ Testing available slots for today..."
  slots = calendar.find_available_slots(date: Date.current)
  puts "✅ Found #{slots.count} available slots for today"
  
  if slots.any?
    puts "\n🕐 Available slots:"
    slots.first(3).each do |slot|
      puts "  - #{slot[:start_time].strftime('%I:%M %p')} to #{slot[:end_time].strftime('%I:%M %p')}"
    end
  end
  
  # Test creating a test event (optional)
  puts "\n📝 Testing event creation..."
  test_summary = "Test Event from Advisor AI"
  start_time = 1.hour.from_now
  end_time = 2.hours.from_now
  
  event = calendar.create_event(
    summary: test_summary,
    description: "This is a test event created by Advisor AI",
    start_time: start_time,
    end_time: end_time,
    location: "Test Location"
  )
  
  puts "✅ Test event created successfully: #{event[:id]}"
  puts "   Summary: #{event[:summary]}"
  puts "   Time: #{event[:start_time]} to #{event[:end_time]}"
  
  puts "\n🎉 All calendar tests passed!"
  
rescue => e
  puts "❌ Calendar test failed: #{e.class} - #{e.message}"
  puts e.backtrace.first(5).join("\n")
  exit 1
end 
#!/usr/bin/env ruby

# Test script for HubSpot integration
# Run with: docker compose run web ruby test_hubspot.rb

require_relative 'config/environment'

puts "Testing HubSpot Integration..."
puts "=============================="

# Find a user with HubSpot access
user = User.where.not(hubspot_access_token: nil).first

if user.nil?
  puts "❌ No users found with HubSpot access tokens"
  puts "Please connect a HubSpot account first by visiting the app and clicking 'Connect HubSpot'"
  exit 1
end

puts "✅ Found user: #{user.email}"

begin
  # Test HubSpot client initialization
  puts "\n🔧 Testing HubSpot client initialization..."
  hubspot = HubspotClient.new(user)
  puts "✅ HubSpot client initialized successfully"
  
  # Test contact search
  puts "\n👥 Testing contact search..."
  contacts = hubspot.search_contacts("test")
  puts "✅ Found #{contacts.count} contacts"
  
  if contacts.any?
    puts "\n📋 Sample contacts:"
    contacts.first(3).each do |contact|
      name = [contact[:first_name], contact[:last_name]].compact.join(' ')
      puts "  - #{name} (#{contact[:email]})"
    end
  end
  
  # Test creating a contact
  puts "\n📝 Testing contact creation..."
  result = hubspot.create_contact(
    name: "Test Contact from Advisor AI",
    email: "test-#{Time.current.to_i}@example.com",
    notes: "Created by Advisor AI test script"
  )
  puts "✅ #{result}"
  
  # Test adding a note to a contact
  puts "\n📝 Testing note addition..."
  if contacts.any?
    contact_email = contacts.first[:email]
    result = hubspot.add_contact_note(
      contact_email: contact_email,
      note: "Test note from Advisor AI - #{Time.current.strftime('%Y-%m-%d %H:%M:%S')}"
    )
    puts "✅ #{result}"
  else
    puts "⚠️  Skipping note test - no contacts found"
  end
  
  # Test creating a deal
  puts "\n💰 Testing deal creation..."
  result = hubspot.create_deal(
    name: "Test Deal from Advisor AI",
    amount: 5000,
    contact_email: contacts.first&.dig(:email)
  )
  puts "✅ #{result}"
  
  puts "\n🎉 All HubSpot tests passed!"
  
rescue => e
  puts "❌ HubSpot test failed: #{e.class} - #{e.message}"
  puts e.backtrace.first(5).join("\n")
  exit 1
end 
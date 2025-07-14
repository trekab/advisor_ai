require 'net/http'
require 'uri'
require 'json'

class HubspotOauthClient
  HUBSPOT_AUTH_URL = 'https://app.hubspot.com/oauth/authorize'
  HUBSPOT_TOKEN_URL = 'https://api.hubapi.com/oauth/v1/token'
  
  def initialize
    @client_id = ENV['HUBSPOT_CLIENT_ID']
    @client_secret = ENV['HUBSPOT_CLIENT_SECRET']
    @redirect_uri = ENV['HUBSPOT_REDIRECT_URI'] || "#{ENV['APP_URL']}/auth/hubspot/callback"
  end

  def authorization_url(state = nil)
    params = {
      client_id: @client_id,
      redirect_uri: @redirect_uri,
      scope: 'crm.objects.contacts.read crm.objects.contacts.write crm.objects.companies.read crm.objects.deals.read crm.objects.deals.write',
      state: state
    }
    
    query_string = params.map { |k, v| "#{k}=#{CGI.escape(v.to_s)}" }.join('&')
    "#{HUBSPOT_AUTH_URL}?#{query_string}"
  end

  def exchange_code_for_token(code)
    uri = URI(HUBSPOT_TOKEN_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/x-www-form-urlencoded'
    
    body = {
      grant_type: 'authorization_code',
      client_id: @client_id,
      client_secret: @client_secret,
      redirect_uri: @redirect_uri,
      code: code
    }
    
    request.body = body.map { |k, v| "#{k}=#{CGI.escape(v.to_s)}" }.join('&')
    
    response = http.request(request)
    
    if response.code == '200'
      JSON.parse(response.body)
    else
      Rails.logger.error("[HubspotOauthClient] Token exchange failed: #{response.code} - #{response.body}")
      raise "Failed to exchange code for token: #{response.body}"
    end
  rescue => e
    Rails.logger.error("[HubspotOauthClient] Token exchange error: #{e.class} - #{e.message}")
    raise "Failed to authenticate with HubSpot: #{e.message}"
  end

  def refresh_token(refresh_token)
    uri = URI(HUBSPOT_TOKEN_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/x-www-form-urlencoded'
    
    body = {
      grant_type: 'refresh_token',
      client_id: @client_id,
      client_secret: @client_secret,
      refresh_token: refresh_token
    }
    
    request.body = body.map { |k, v| "#{k}=#{CGI.escape(v.to_s)}" }.join('&')
    
    response = http.request(request)
    
    if response.code == '200'
      JSON.parse(response.body)
    else
      Rails.logger.error("[HubspotOauthClient] Token refresh failed: #{response.code} - #{response.body}")
      raise "Failed to refresh token: #{response.body}"
    end
  rescue => e
    Rails.logger.error("[HubspotOauthClient] Token refresh error: #{e.class} - #{e.message}")
    raise "Failed to refresh HubSpot token: #{e.message}"
  end
end 
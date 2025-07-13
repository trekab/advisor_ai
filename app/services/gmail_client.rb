require 'google/apis/gmail_v1'
require 'googleauth'
require 'signet/oauth_2/client'
require 'mail'
require 'base64'

class GmailClient
  def initialize(user)
    @user = user
    @service = Google::Apis::GmailV1::GmailService.new
    @service.authorization = build_authorizer
  end

  def fetch_recent(limit = 10)
    result = @service.list_user_messages('me', max_results: limit)
    return [] unless result.messages

    result.messages.map do |msg|
      @service.get_user_message('me', msg.id)
    end
  rescue Google::Apis::AuthorizationError => e
    Rails.logger.error("[GmailClient] Auth error for user #{@user.id}: #{e.message}")
    []
  end

  def send_email(to:, subject:, body:)
    message = Mail.new do
      from    @user.email
      to      to
      subject subject
      text_part do
        body body
      end
    end
    encoded_message = Base64.urlsafe_encode64(message.to_s)
    msg_obj = Google::Apis::GmailV1::Message.new(raw: encoded_message)
    @service.send_user_message('me', msg_obj)
  end

  private

  def build_authorizer
    Signet::OAuth2::Client.new(
      client_id: ENV['GOOGLE_CLIENT_ID'],
      client_secret: ENV['GOOGLE_CLIENT_SECRET'],
      token_credential_uri: 'https://oauth2.googleapis.com/token',
      access_token: @user.google_access_token,
      refresh_token: @user.google_refresh_token
    ).tap(&:fetch_access_token!)
  end
end

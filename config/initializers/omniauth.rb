Rails.application.config.middleware.use OmniAuth::Builder do
  provider :google_oauth2,
           ENV['GOOGLE_CLIENT_ID'],
           ENV['GOOGLE_CLIENT_SECRET'],
           {
             scope: 'email profile https://www.googleapis.com/auth/gmail.readonly https://www.googleapis.com/auth/calendar https://www.googleapis.com/auth/calendar.events',
             access_type: 'offline',
             prompt: 'consent',
             include_granted_scopes: true
           }
end

OmniAuth.config.allowed_request_methods = [:post, :get]
OmniAuth.config.silence_get_warning = true

# Better error handling
OmniAuth.config.on_failure = proc { |env|
  message_key = env['omniauth.error.type']
  error_description = env['omniauth.error']&.error_reason
  new_path = "/auth/failure?message=#{message_key}&error_description=#{error_description}"
  [302, {'Location' => new_path, 'Content-Type'=> 'text/html'}, []]
}

require 'bundler/setup'
require 'sinatra'
require 'sinatra/reloader' if development?

require 'tilt/erb'

require 'net/http'
require 'uri'
require 'json'

configure do
  # set webhook url
  if ENV['SLACK_WEBHOOK_URL']
    set :slack_webhook_url, ENV['SLACK_WEBHOOK_URL']
  else
    set :slack_webhook_url, File.read(File.join __FILE__, "./slack_webhook_url")
  end

  set :protect_from_csrf, true

  enable :sessions
  set :sessions, key: "kakioki"
  set :session_secret, SecureRandom.uuid
end

helpers do
  def h(text)
    Rack::Utils.escape_html text
  end

  def build_message(from, payload)
    if from.empty?
      "Anonymous message at #{Time.now}\n----\n#{payload}"
    else
      "Message from #{from} at #{Time.now}\n----\n#{payload}"
    end
  end
end


get '/' do
  session[:visit] ||= Time.now
  erb :index
end

get '/kakioki' do
  redirect '/'
end

post '/kakioki' do
  status 500 if session[:visit].nil? ||
                session[:sent] ||
                params[:name].nil? ||
                params[:payload].nil?

  uri = URI.parse settings.slack_webhook_url
  https = Net::HTTP.new uri.host, uri.port
  https.use_ssl = true

  req = Net::HTTP::Post.new uri.request_uri
  req.body = { text: build_message(params[:name], params[:payload]) }.to_json
  res = https.request(req)

  unless res.code == "200"
    [:name, :payload].each do |k|
      session[k] = params[k]
    end
    session[:warn] = "We're sorry but unknown error has been occured. Please try again later."
    redirect '/'
  else
    session[:sent] = Time.now
    erb :thanks
  end
end


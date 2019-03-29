require 'base64'
require 'sinatra'
require 'json'
require 'uri'
require 'net/http'
require 'httparty'

before do
    $stdout.sync = true
    @routerDomain = ENV["ROUTER_DOMAIN"]
    @spotifyClient = ENV["SPOTIFY_CLIENT"]
    @spotifySecret = ENV["SPOTIFY_SECRET"]
end

configure do
    @@redirectUri = "http://localhost:4567/token"
    if ENV.key? "VCAP_APPLICATION" 
        jEnv = JSON.parse(ENV["VCAP_APPLICATION"])
        @@redirectUri = "https://#{jEnv["application_uris"].first}/token"
    end

    @@code = nil
    @@token = nil
    @@expires = nil
    @@refresh = nil
end

def dispatch(intentName, params, fullRequest)
    uri = "http://#{intentName.downcase}.#{@routerDomain}"
    headers = {"Content-Type" => "application/json"}
    puts "Invoking action URI: #{uri}"

    if intentName.downcase == "spotify"
        if Time.new > @@expires
            refreshToken()
        end
        params["token"] = @@token
    end

    puts "With params: #{params.to_json}"

    response = HTTParty.post(uri, :headers => headers, :body => params.to_json)

    # 404 from backend service
    if response.code == 404
        puts "ENOBACKEND: 404"
        return fullRequest["queryResult"]["fulfillmentText"]
    else
        puts "ACTION RESPONSE: #{response.body}"
        return build_response(response.body)
    end
end

def build_response(resp)
    return {"fulfillmentText": resp}.to_json
end

post '/' do
    body = request.body.read
    puts body
    jBody = JSON.parse(body)
    return dispatch(jBody["queryResult"]["intent"]["displayName"], jBody["queryResult"]["parameters"], jBody)
end

get '/' do
    if not @@code.nil? and Time.now < @@expires
        return "Logged in to Spotify! Token expires in #{(@@expires - Time.now).floor} seconds"
    else
        return "Welcome!"
    end
end

get '/spotify' do   
    scopes = "user-modify-playback-state"
    redirect 'https://accounts.spotify.com/authorize?response_type=code&client_id=' + @spotifyClient + "&scope=" + URI.encode(scopes) + "&redirect_uri=" + @@redirectUri
end

get '/token' do
    
    # Store auth token
    @@code = params["code"]

    # Get access and refresh roken
    body = {
        "grant_type": "authorization_code",
        "code": @@code,
        "redirect_uri": @@redirectUri
    }

    encodedAuth = Base64.strict_encode64("#{@spotifyClient}:#{@spotifySecret}")
    headers = {
        "Authorization": "Basic #{encodedAuth}"
    }

    response = HTTParty.post("https://accounts.spotify.com/api/token", :body => body, :headers => headers)
    jBody = JSON.parse(response.body)

    @@token = jBody["access_token"]
    @@expires = Time.now + jBody["expires_in"].to_i
    @@refresh = jBody["refresh_token"]

    redirect "/"
end

def refreshToken
    puts "Refreshing token"
    body = {
        "grant_type": "refresh_token",
        "refresh_token": @@refresh
    }

    encodedAuth = Base64.strict_encode64("#{@spotifyClient}:#{@spotifySecret}")
    headers = {
        "Authorization": "Basic #{encodedAuth}"
    }

    response = HTTParty.post("https://accounts.spotify.com/api/token", :body => body, :headers => headers)
    jBody = JSON.parse(response.body)

    @@token = jBody["access_token"]
    @@expires = Time.now + jBody["expires_in"].to_i
end
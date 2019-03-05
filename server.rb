require 'sinatra'
require 'json'
require 'uri'
require 'net/http'
require 'httparty'

before do
    @routerDomain = ENV["ROUTER_DOMAIN"]
end

def dispatch(intentName, params)
    uri = "http://#{intentName.downcase}.#{@routerDomain}"
    headers = {"Content-Type": "application/json"}
    puts uri
    puts headers
    response = HTTParty.post(uri, :headers => headers, :body => params.to_json)
    return build_response(response.body)
end

def build_response(resp)
    return {"fulfillmentText": resp}.to_json
end

post '/' do
    body = request.body.read
    jBody = JSON.parse(body)
    return dispatch(jBody["queryResult"]["intent"]["displayName"], jBody["queryResult"]["parameters"])
end
# coding: utf-8
require 'date'
require "line/bot"
require "sinatra"
require "config"

set :root, File.dirname(__FILE__)
register Config
set :port, Settings.port
set :bind, Settings.bind_address

class Restaurent
  attr_accessor :name, :closing_days

  def initialize(name, closing_days = [])
    @name = name
    @closing_days = closing_days
  end
end

def restaurents
  return @restaurents if @restaurents
  @restaurents = []
  File.open("./data.tsv") do |f|
    f.readline
    f.each do |line|
      data = line.strip.split("\t")
      name = data[0]
      if data.count == 1
        rest = Restaurent.new name
      else
        closing_days = data[1].split(",").map(&:to_i)
        rest = Restaurent.new name, closing_days
      end
      @restaurents.push rest
    end
  end
  @restaurents
end

restaurents

def client
  @client ||= Line::Bot::Client.new do |config|
    config.channel_secret = Settings.line.channel_secret
    config.channel_token = Settings.line.channel_token
  end
end

post "/webhook" do
  body = request.body.read

  signature = request.env["HTTP_X_LINE_SIGNATURE"]
  unless client.validate_signature(body, signature)
    error 400 do
      "Bad Request"
    end
  end

  events = client.parse_events_from(body)
  events.each do |event|
    case event
    when Line::Bot::Event::Message
      case event.type
      when Line::Bot::Event::MessageType::Text
        user_message = event.message["text"]
        if user_message.include?("雷姆") && user_message.include?("吃什麼")
          current_week = Date.today.strftime("%u").to_i
          loop do
            random_rest = @restaurents.sample
            break unless random_rest.closing_days.include? current_week
          end

          message = {
            type: "text",
            text: "我找找... 吃 #{random_rest.name} 好了!"
          }

          client.reply_message(event["replyToken"], message)
        end
      end
    end
  end

  "OK"
end

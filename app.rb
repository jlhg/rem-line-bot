require "config"
require "line/bot"
require "sinatra"

set :root, File.dirname(__FILE__)
register Config

def client
  @client ||= Line::Bot::Client.new { |config|
    config.channel_secret = Settings.line.channel_secret
    config.channel_token = Settings.line.channel_token
  }
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
        message = {
          type: "text",
          text: event.message["text"]
        }
        client.reply_message(event["replyToken"], message)
      end
    end
  end

  "OK"
end

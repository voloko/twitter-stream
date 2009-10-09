# twitter-stream

Simple Ruby client library for [twitter streaming API](http://apiwiki.twitter.com/Streaming-API-Documentation). 
Uses [EventMachine](http://rubyeventmachine.com/) for connection handling. Adheres to twitter's [reconnection guidline](http://apiwiki.twitter.com/Streaming-API-Documentation#Connecting).

JSON format only.

## Usage

    EventMachine::run {
      stream = Twitter::JSONStream.connect(
        :path    => '/1/statuses/filter.json?track=football',
        :auth    => 'LOGIN:PASSWORD',
      )

      stream.each_item do |item|
        # do someting with unparsed JSON item
      end

      stream.on_error do |message|
        # log or something
      end
    }
    

## Examples

Open examples/reader.rb. Replace LOGIN:PASSWORD with your real twitter login and password. And
    ruby examples/reader.rb


require 'rubygems'

gem 'rspec', '>= 2.5.0'
require 'rspec'
require 'rspec/mocks'

require 'twitter/json_stream'

def fixture_path(path)
  File.join(File.dirname(__FILE__), '..', 'fixtures', path)
end

def read_fixture(path)
  File.read(fixture_path(path))
end

def connect_stream(opts={}, &blk)
  EM.run {
    opts.merge!(:host => Host, :port => Port)
    stop_in = opts.delete(:stop_in) || 0.5
    unless opts[:start_server] == false
      EM.start_server Host, Port, JSONServer
    end
    @stream = JSONStream.connect(opts)
    blk.call if blk
    EM.add_timer(stop_in){ EM.stop }
  }
end

def http_response(status_code, status_text, headers, body)
  res = "HTTP/1.1 #{status_code} #{status_text}\r\n"
  headers = {
    "Content-Type"=>"application/json",
    "Transfer-Encoding"=>"chunked"
  }.merge(headers)
  headers.each do |key,value|
    res << "#{key}: #{value}\r\n"
  end
  res << "\r\n"
  if headers["Transfer-Encoding"] == "chunked" && body.kind_of?(Array)
    body.each do |data|
      res << http_chunk(data)
    end
  else
    res << body
  end
  res
end

def http_chunk(data)
  # See http://www.w3.org/Protocols/rfc2616/rfc2616-sec3.html#sec3.6.1
  "#{data.length.to_s(16)}\r\n#{data}\r\n"
end

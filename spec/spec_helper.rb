require 'rubygems'
lib_path = File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift lib_path unless $LOAD_PATH.include?(lib_path)

gem 'rspec'
require 'spec'
require 'spec/mocks'

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
    EM.start_server Host, Port, JSONServer
    @stream = JSONStream.connect(opts)
    blk.call if blk
    EM.add_timer(stop_in){ EM.stop }
  }
end
require File.dirname(__FILE__) + '/../spec_helper.rb'
require 'twitter/json_stream'

include Twitter

describe JSONStream do
  
  context "on create" do
    
    it "should return stream" do
      EM.should_receive(:connect).and_return('TEST INSTANCE')
      stream = JSONStream.connect {}
      stream.should == 'TEST INSTANCE'
    end
    
    it "should define default properties" do
      EM.should_receive(:connect).with do |host, port, handler, opts|
        host.should == 'stream.twitter.com'
        port.should == 80
        opts[:path].should == '/1/statuses/filter.json'
        opts[:method].should == 'GET'
      end
      stream = JSONStream.connect {}
    end
    
  end
  
  
  Host = "127.0.0.1"
  Port = 9550
  
  class JSONServer < EM::Connection
    attr_accessor :data
    def receive_data data
      $recieved_data = data
      send_data $data_to_send
      EventMachine.next_tick {
        close_connection if $close_connection
      }
    end
  end
  
  context "on valid stream" do
    before :each do
      $data_to_send = read_fixture('twitter/basic_http.txt')
      $recieved_data = ''
      $close_connection = false
    end
    
    it "should parse headers" do
      EM.run {
        EM.start_server Host, Port, JSONServer
        @stream = JSONStream.connect :host => Host, :port => Port
        EM.add_timer(0.5){ EM.stop }
      }
      @stream.code.should == 200
      @stream.headers[0].downcase.should include 'content-type'
    end
    
    it "should parse headers even after connection close" do
      EM.run {
        $close_connection = true
        EM.start_server Host, Port, JSONServer
        @stream = JSONStream.connect :host => Host, :port => Port
        EM.add_timer(0.5){ EM.stop }
      }
      @stream.code.should == 200
      @stream.headers[0].downcase.should include 'content-type'
    end
    
    it "should extract records" do
      EM.run {
        EM.start_server Host, Port, JSONServer
        @stream = JSONStream.connect :host => Host, :port => Port, :user_agent => 'TEST_USER_AGENT'
        EM.add_timer(0.5){ EM.stop }
      }
      $recieved_data.upcase.should include('USER-AGENT: TEST_USER_AGENT')
    end
    
    it "should send correct user agent" do
      EM.run {
        $close_connection = true
        EM.start_server Host, Port, JSONServer
        @stream = JSONStream.connect :host => Host, :port => Port
        EM.add_timer(0.5){ EM.stop }
      }
    end
  end
  
  context "on network failure" do
    before :each do
      $data_to_send = ''
      $close_connection = true
    end
    
    it "should reconnect on network failure" do
      EM.run {
        EM.start_server Host, Port, JSONServer
        @stream = JSONStream.connect :host => Host, :port => Port
        @stream.should_receive(:reconnect)
        EM.add_timer(0.5){ EM.stop }
      }
    end
    
    it "should reconnect with 0.25 at base" do
      EM.run {
        EM.start_server Host, Port, JSONServer
        @stream = JSONStream.connect :host => Host, :port => Port
        @stream.should_receive(:reconnect_after).with(0.25)
        EM.add_timer(0.5){ EM.stop }
      }
    end
    
    it "should reconnect with linear timeout" do
      EM.run {
        EM.start_server Host, Port, JSONServer
        @stream = JSONStream.connect :host => Host, :port => Port
        @stream.nf_last_reconnect = 1
        @stream.should_receive(:reconnect_after).with(1.25)
        EM.add_timer(0.5){ EM.stop }
      }
    end
    
    it "should stop reconnecting after 100 times" do
      EM.run {
        EM.start_server Host, Port, JSONServer
        @stream = JSONStream.connect :host => Host, :port => Port
        @stream.reconnect_retries = 100
        @stream.should_not_receive(:reconnect_after)
        EM.add_timer(0.5){ EM.stop }
      }
    end
    
    it "should notify after reconnect limit is reached" do
      timeout, retries = nil, nil
      EM.run {
        EM.start_server Host, Port, JSONServer
        @stream = JSONStream.connect :host => Host, :port => Port
        @stream.on_max_reconnects do |t, r|
          timeout, retries = t, r
        end
        @stream.reconnect_retries = 100
        EM.add_timer(0.5){ EM.stop }
      }
      timeout.should == 0.25
      retries.should == 101
    end
  end
  
  context "on application failure" do
    before :each do
      $data_to_send = 'HTTP/1.1 401 Unauthorized\r\nWWW-Authenticate: Basic realm="Firehose"\r\n\r\n1'
      $close_connection = true
    end
    
    it "should reconnect on application failure 10 at base" do
      EM.run {
        EM.start_server Host, Port, JSONServer
        @stream = JSONStream.connect :host => Host, :port => Port
        @stream.should_receive(:reconnect_after).with(10)
        EM.add_timer(0.5){ EM.stop }
      }
    end
    
    it "should reconnect with exponential timeout" do
      EM.run {
        EM.start_server Host, Port, JSONServer
        @stream = JSONStream.connect :host => Host, :port => Port
        @stream.af_last_reconnect = 160
        @stream.should_receive(:reconnect_after).with(320)
        EM.add_timer(0.5){ EM.stop }
      }
    end
    
    it "should not try to reconnect after limit is reached" do
      EM.run {
        EM.start_server Host, Port, JSONServer
        @stream = JSONStream.connect :host => Host, :port => Port
        @stream.af_last_reconnect = 320
        @stream.should_not_receive(:reconnect_after)
        EM.add_timer(0.5){ EM.stop }
      }
    end
  end
  
  
  
end


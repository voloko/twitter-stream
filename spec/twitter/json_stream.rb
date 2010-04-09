$:.unshift "."
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
    
    it "should connect to the proxy if provided" do
      EM.should_receive(:connect).with do |host, port, handler, opts|
        host.should == 'my-proxy'
        port.should == 8080
        opts[:host].should == 'stream.twitter.com'
        opts[:port].should == 80
        opts[:proxy].should == 'http://my-proxy:8080'
      end
      stream = JSONStream.connect(:proxy => "http://my-proxy:8080") {}
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
    attr_reader :stream
    before :each do
      $data_to_send = read_fixture('twitter/basic_http.txt')
      $recieved_data = ''
      $close_connection = false
    end
    
    it "should parse headers" do
      connect_stream
      stream.code.should == 200
      stream.headers[0].downcase.should include 'content-type'
    end
    
    it "should parse headers even after connection close" do
      connect_stream
      stream.code.should == 200
      stream.headers[0].downcase.should include 'content-type'
    end
    
    it "should extract records" do
      connect_stream :user_agent => 'TEST_USER_AGENT'
      $recieved_data.upcase.should include('USER-AGENT: TEST_USER_AGENT')
    end
    
    it "should send correct user agent" do
      connect_stream
    end
  end
  
  context "on network failure" do
    attr_reader :stream
    before :each do
      $data_to_send = ''
      $close_connection = true
    end
    
    it "should timeout on inactivity" do
      connect_stream :stop_in => 1.5 do
        stream.should_receive(:reconnect)        
      end
    end    
    
    it "should reconnect on network failure" do
      connect_stream do
        stream.should_receive(:reconnect)
      end
    end
    
    it "should reconnect with 0.25 at base" do
      connect_stream do
        stream.should_receive(:reconnect_after).with(0.25)
      end
    end
    
    it "should reconnect with linear timeout" do
      connect_stream do
        stream.nf_last_reconnect = 1
        stream.should_receive(:reconnect_after).with(1.25)
      end
    end
    
    it "should stop reconnecting after 100 times" do
      connect_stream do
        stream.reconnect_retries = 100
        stream.should_not_receive(:reconnect_after)
      end
    end
    
    it "should notify after reconnect limit is reached" do
      timeout, retries = nil, nil
      connect_stream do
        stream.on_max_reconnects do |t, r|
          timeout, retries = t, r
        end
        stream.reconnect_retries = 100
      end
      timeout.should == 0.25
      retries.should == 101
    end
  end
  
  context "on application failure" do
    attr_reader :stream
    before :each do
      $data_to_send = 'HTTP/1.1 401 Unauthorized\r\nWWW-Authenticate: Basic realm="Firehose"\r\n\r\n1'
      $close_connection = true
    end
    
    it "should reconnect on application failure 10 at base" do
      connect_stream do
        stream.should_receive(:reconnect_after).with(10)
      end
    end
    
    it "should reconnect with exponential timeout" do
      connect_stream do
        stream.af_last_reconnect = 160
        stream.should_receive(:reconnect_after).with(320)
      end
    end
    
    it "should not try to reconnect after limit is reached" do
      connect_stream do
        stream.af_last_reconnect = 320
        stream.should_not_receive(:reconnect_after)
      end
    end
  end  
end
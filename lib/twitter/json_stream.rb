require 'eventmachine'
require 'em/buftok'
require 'uri'
require 'simple_oauth'
require 'http/parser'

module Twitter
  class JSONStream < EventMachine::Connection
    MAX_LINE_LENGTH = 1024*1024

    # network failure reconnections
    NF_RECONNECT_START = 0.25
    NF_RECONNECT_ADD   = 0.25
    NF_RECONNECT_MAX   = 16

    # app failure reconnections
    AF_RECONNECT_START = 10
    AF_RECONNECT_MUL   = 2

    RECONNECT_MAX   = 320
    RETRIES_MAX     = 10

    NO_DATA_TIMEOUT = 90

    DEFAULT_OPTIONS = {
      :method         => 'GET',
      :path           => '/',
      :content_type   => "application/x-www-form-urlencoded",
      :content        => '',
      :path           => '/1/statuses/filter.json',
      :host           => 'stream.twitter.com',
      :port           => 443,
      :ssl            => true,
      :user_agent     => 'TwitterStream',
      :timeout        => 0,
      :proxy          => ENV['HTTP_PROXY'],
      :auth           => nil,
      :oauth          => {},
      :filters        => [],
      :params         => {},
      :auto_reconnect => true
    }

    attr_accessor :code
    attr_accessor :headers
    attr_accessor :nf_last_reconnect
    attr_accessor :af_last_reconnect
    attr_accessor :reconnect_retries
    attr_accessor :last_data_received_at
    attr_accessor :proxy

    def self.connect options = {}
      options[:port] = 443 if options[:ssl] && !options.has_key?(:port)
      options = DEFAULT_OPTIONS.merge(options)

      host = options[:host]
      port = options[:port]

      if options[:proxy]
        proxy_uri = URI.parse(options[:proxy])
        host = proxy_uri.host
        port = proxy_uri.port
      end

      connection = EventMachine.connect host, port, self, options
      connection
    end

    def initialize options = {}
      @options = DEFAULT_OPTIONS.merge(options) # merge in case initialize called directly
      @gracefully_closed = false
      @nf_last_reconnect = nil
      @af_last_reconnect = nil
      @reconnect_retries = 0
      @immediate_reconnect = false
      @on_inited_callback = options.delete(:on_inited)
      @proxy = URI.parse(options[:proxy]) if options[:proxy]
      @last_data_received_at = nil
    end

    def each_item &block
      @each_item_callback = block
    end

    def on_error &block
      @error_callback = block
    end

    def on_reconnect &block
      @reconnect_callback = block
    end

    # Called when no data has been received for NO_DATA_TIMEOUT seconds.
    # Reconnecting is probably in order as per the Twitter recommendations
    def on_no_data &block
      @no_data_callback = block
    end

    def on_max_reconnects &block
      @max_reconnects_callback = block
    end

    def on_close &block
      @close_callback = block
    end

    def stop
      @gracefully_closed = true
      close_connection
    end

    def immediate_reconnect
      @immediate_reconnect = true
      @gracefully_closed = false
      close_connection
    end

    def unbind
      if @state == :stream && !@buffer.empty?
        parse_stream_line(@buffer.flush)
      end
      schedule_reconnect if @options[:auto_reconnect] && !@gracefully_closed
      @close_callback.call if @close_callback
      @state = :init
    end

    # Receives raw data from the HTTP connection and pushes it into the
    # HTTP parser which then drives subsequent callbacks.
    def receive_data(data)
      @last_data_received_at = Time.now
      @parser << data
    end

    def connection_completed
      start_tls if @options[:ssl]
      send_request
    end

    def post_init
      reset_state
      @on_inited_callback.call if @on_inited_callback
      @reconnect_timer = EventMachine.add_periodic_timer(5) do
        if @gracefully_closed
          @reconnect_timer.cancel
        elsif @last_data_received_at && Time.now - @last_data_received_at > NO_DATA_TIMEOUT
          no_data
        end
      end
    end

  protected
    def no_data
      @no_data_callback.call if @no_data_callback
    end

    def schedule_reconnect
      timeout = reconnect_timeout
      @reconnect_retries += 1
      if timeout <= RECONNECT_MAX && @reconnect_retries <= RETRIES_MAX
        reconnect_after(timeout)
      else
        @max_reconnects_callback.call(timeout, @reconnect_retries) if @max_reconnects_callback
      end
    end

    def reconnect_after timeout
      @reconnect_callback.call(timeout, @reconnect_retries) if @reconnect_callback

      if timeout == 0
        reconnect @options[:host], @options[:port]
      else
        EventMachine.add_timer(timeout) do
          reconnect @options[:host], @options[:port]
        end
      end
    end

    def reconnect_timeout
      if @immediate_reconnect
        @immediate_reconnect = false
        return 0
      end

      if (@code == 0) # network failure
        if @nf_last_reconnect
          @nf_last_reconnect += NF_RECONNECT_ADD
        else
          @nf_last_reconnect = NF_RECONNECT_START
        end
        [@nf_last_reconnect,NF_RECONNECT_MAX].min
      else
        if @af_last_reconnect
          @af_last_reconnect *= AF_RECONNECT_MUL
        else
          @af_last_reconnect = AF_RECONNECT_START
        end
        @af_last_reconnect
      end
    end

    def reset_state
      set_comm_inactivity_timeout @options[:timeout] if @options[:timeout] > 0
      @code    = 0
      @headers = {}
      @state   = :init
      @buffer  = BufferedTokenizer.new("\r", MAX_LINE_LENGTH)
      @stream  = ''

      @parser  = Http::Parser.new
      @parser.on_headers_complete = method(:handle_headers_complete)
      @parser.on_body = method(:receive_stream_data)
    end

    # Called when the status line and all headers have been read from the
    # stream.
    def handle_headers_complete(headers)
      @code = @parser.status_code.to_i
      if @code != 200
        receive_error("invalid status code: #{@code}.")
      end
      self.headers = headers
      @state = :stream
    end

    # Called every time a chunk of data is read from the connection once it has
    # been opened and after the headers have been processed.
    def receive_stream_data(data)
      begin
        @buffer.extract(data).each do |line|
          parse_stream_line(line)
        end
        @stream  = ''
      rescue => e
        receive_error("#{e.class}: " + [e.message, e.backtrace].flatten.join("\n\t"))
        close_connection
        return
      end
    end

    def send_request
      data = []
      request_uri = @options[:path]

      if @proxy
        # proxies need the request to be for the full url
        request_uri = "#{uri_base}:#{@options[:port]}#{request_uri}"
      end

      content = @options[:content]

      unless (q = query).empty?
        if @options[:method].to_s.upcase == 'GET'
          request_uri << "?#{q}"
        else
          content = q
        end
      end

      data << "#{@options[:method]} #{request_uri} HTTP/1.1"
      data << "Host: #{@options[:host]}"
      data << 'Accept: */*'
      data << "User-Agent: #{@options[:user_agent]}" if @options[:user_agent]

      if @options[:auth]
        data << "Authorization: Basic #{[@options[:auth]].pack('m').delete("\r\n")}"
      elsif @options[:oauth]
        data << "Authorization: #{oauth_header}"
      end

      if @proxy && @proxy.user
        data << "Proxy-Authorization: Basic " + ["#{@proxy.user}:#{@proxy.password}"].pack('m').delete("\r\n")
      end
      if ['POST', 'PUT'].include?(@options[:method])
        data << "Content-type: #{@options[:content_type]}"
        data << "Content-length: #{content.length}"
      end

      if @options[:headers]
        @options[:headers].each do |name,value|
            data << "#{name}: #{value}"
        end
      end

      data << "\r\n"

      send_data data.join("\r\n") << content
    end

    def receive_error e
      @error_callback.call(e) if @error_callback
    end

    def parse_stream_line ln
      ln.strip!
      unless ln.empty?
        if ln[0,1] == '{' || ln[ln.length-1,1] == '}'
          @stream << ln
          if @stream[0,1] == '{' && @stream[@stream.length-1,1] == '}'
            @each_item_callback.call(@stream) if @each_item_callback
            @stream = ''
          end
        end
      end
    end

    def reset_timeouts
      set_comm_inactivity_timeout @options[:timeout] if @options[:timeout] > 0
      @nf_last_reconnect = @af_last_reconnect = nil
      @reconnect_retries = 0
    end

    #
    # URL and request components
    #

    # :filters => %w(miama lebron jesus)
    # :oauth => {
    #   :consumer_key    => [key],
    #   :consumer_secret => [token],
    #   :access_key      => [access key],
    #   :access_secret   => [access secret]
    # }
    def oauth_header
      uri = uri_base + @options[:path].to_s

      # The hash SimpleOAuth accepts is slightly different from that of
      # ROAuth.  To preserve backward compatability, fix the cache here
      # so that the arguments passed in don't need to change.
      oauth = {
        :consumer_key => @options[:oauth][:consumer_key],
        :consumer_secret => @options[:oauth][:consumer_secret],
        :token => @options[:oauth][:access_key],
        :token_secret => @options[:oauth][:access_secret]
      }

      data = ['POST', 'PUT'].include?(@options[:method]) ? params : {}

      SimpleOAuth::Header.new(@options[:method], uri, data, oauth)
    end

    # Scheme (https if ssl, http otherwise) and host part of URL
    def uri_base
      "http#{'s' if @options[:ssl]}://#{@options[:host]}"
    end

    # Normalized query hash of escaped string keys and escaped string values
    # nil values are skipped
    def params
      flat = {}
      @options[:params].merge( :track => @options[:filters] ).each do |param, val|
        next if val.to_s.empty? || (val.respond_to?(:empty?) && val.empty?)
        val = val.join(",") if val.respond_to?(:join)
        flat[param.to_s] = val.to_s
      end
      flat
    end

    def query
      params.map{|param, value| [escape(param), escape(value)].join("=")}.sort.join("&")
    end

    def escape str
      URI.escape(str.to_s, /[^a-zA-Z0-9\-\.\_\~]/)
    end
  end
end

# encoding: utf-8
require "logstash/outputs/base"
require "logstash/namespace"
require "uri"
require "net/http"
require "net/https"
require "stud/buffer"
require "zlib"
require 'time'
require 'json'

# 
# This is most useful so you can use logstash to parse and structure
# your logs and ship structured, json events to ThetaPoint.
#
# To use this, you'll need to use a ThetaPoint input with type 'http'
# and 'json logging' enabled.
class LogStash::Outputs::ThetaPoint < LogStash::Outputs::Base

  include Stud::Buffer

  config_name "thetapoint"

  # The hostname to send logs to. 
  config :host, :validate => :string, :default => "api.theta-point.com"
  config :port, :validate => :number, :default => 443
  config :path, :validate => :string, :default => "bulk"

  # The thetapoint http input key to send to.
  #     https://thetapoint03.theta-point.com/inputs/abcdef12-3456-7890-abcd-ef0123456789
  #                                           ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  #                                           \---------->   key   <-------------/
  #
  # You can use %{foo} field lookups here if you need to pull the api key from
  # the event. This is mainly aimed at multitenant hosting providers who want
  # to offer shipping a customer's logs to that customer's loggly account.
  config :key, :validate => :string, :required => true

  # Should the log action be sent over https instead of plain http
  config :proto, :validate => :string, :default => "https"

  # Proxy Host
  config :proxy_host, :validate => :string, :default => nil

  # Proxy Port
  config :proxy_port, :validate => :number, :default => nil

  # Proxy Username
  config :proxy_user, :validate => :string, :default => nil

  # Proxy Password
  config :proxy_password, :validate => :password, :default => nil

  # If true, we send an HTTP POST request every "batch_events" events or
  # "batch_timeout" seconds (whichever comes first).
  config :batch, :validate => :boolean, :default => false
  config :batch_events, :validate => :number, :default => 100
  config :batch_timeout, :validate => :number, :default => 5

  config :compress, :validate => :boolean, :default => false

  public
  def register
    if @batch
        buffer_initialize(
            :max_items => @batch_events,
            :max_interval => @batch_timeout,
            :logger => @logger
        )
    end

  end

  public
  def receive(event)
    return unless output?(event)

    @logger.info("receive: #{event}")

    if @batch
        # Stud::Buffer
        @logger.info("receive: Buffer Event")
        buffer_receive(event, event.sprintf(@key))
        return
    end

    @logger.info("receive: Send Single Event")
    send_data(event.to_json, event.sprintf(@key))

  end # def receive

  def send_data(data, key)

    # Comress data
    if @compress
      @logger.info("Deflate start", :now => Time.now.rfc2822, :length => data.length)
      post_data = Zlib::Deflate.deflate(data, Zlib::BEST_COMPRESSION)
      @logger.info("Deflate end", :now => Time.now.rfc2822, :length => post_data.length, :ratio => post_data.length/data.length)
      @path = "zbulk"
    else
      post_data = data
    end

    # Send the data
    @logger.info("ThetaPoint Connect: ",
        :host => @host,
        :port => @port,
        :proxy_host => @proxy_host,
        :proxy_port => @proxy_port, 
        :proxy_user => @proxy_user, 
        :proxy_password => @proxy_password ? @proxy_password.value : nil)
    @http = Net::HTTP.new(@host, @port, @proxy_host, @proxy_port, @proxy_user, @proxy_password.value)
    @logger.info("http", :http => @http)
    if @proto == 'https'
      @http.use_ssl = true
      @http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    end

    begin
      @logger.info("Submit start", :now => Time.now.rfc2822)
      uri = "/#{@path}/#{key}"
      response = @http.request_post(uri, post_data)
      @logger.info("Submit end", :now => Time.now.rfc2822)
      @logger.info("response", :response => response)
      if response.is_a?(Net::HTTPSuccess)
        @logger.info("Event send to ThetaPoint OK!")
      else
        @logger.warn("HTTP error", :error => response.error!)
      end
    rescue Exception => e
      @logger.error("ThetaPoint Unhandled exception", :pd_error => e.backtrace)
    end

  end # def send_data

  # called from Stud::Buffer#buffer_flush when there are events to flush
  def flush(events, key, teardown=false)
    @logger.info("Flush #{events.length} events")
    send_data(events.to_json, key)
  end # def flush

  # called from Stud::Buffer#buffer_flush when an error occurs
  def on_flush_error(e)
    @logger.warn("Failed to send backlog of events to ThetaPoint",
        :exception => e,
        :backtrace => e.backtrace
    )
  end # def on_flush_error

  def teardown
    if @batch
      buffer_flush(:final => true)
    end
  end # def teardown

end # class LogStash::Outputs::ThetaPoint

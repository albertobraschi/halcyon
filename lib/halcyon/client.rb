%w(net/http uri json).each {|dep|require dep}

module Halcyon
  
  # = Building Custom Clients
  # 
  # Once your Halcyon JSON Server App starts to take shape, it may be useful
  # to begin to write tests on expected functionality, and then to implement
  # API calls with a designated Client lib for your Ruby or Rails apps, etc.
  # The Base class provides a standard implementation and several options for
  # wrapping up functionality of your app from the server side into the
  # client side so that you may begin to use response data.
  # 
  # == Creating Your Client
  # 
  # Creating a simple client can be as simple as this:
  # 
  #   class Simple < Halcyon::Client
  #     def greet(name)
  #       get("/hello/#{name}")
  #     end
  #   end
  # 
  # The only thing simply may be actually using the Simple client you just
  # created.
  # 
  # But to actually get in and use the library, one has to take full
  # advantage of the HTTP request methods, +get+, +post+, +put+, and
  # +delete+. These methods simply return the JSON-parsed data from the
  # server, effectively returning a hash with two key values, +status+ which
  # contains the HTTP status code, and +body+ which contains the body of the
  # content returned which can be any number of objects, including, but not
  # limited to Hash, Array, Numeric, Nil, Boolean, String, etc.
  # 
  # You are not limited to what your methods can call: they are arbitrarily
  # and solely up to your whims and needs. It is simply a matter of good
  # design and performance when it comes to structuring and implementing
  # client actions which can be complex or simple series of requests to the
  # server.
  # 
  class Client
    include Exceptions
    
    USER_AGENT = "JSON/#{JSON::VERSION} Compatible (en-US) Halcyon::Client/#{Halcyon.version}".freeze
    CONTENT_TYPE = "application/x-www-form-urlencoded".freeze
    ACCEPT = "application/json, */*".freeze
    
    DEFAULT_OPTIONS = {
      :raise_exceptions => false,
      :encode_post_body_as_json => false
    }
    
    attr_accessor :uri # The server URI
    attr_accessor :headers # Instance-wide headers
    attr_accessor :options # Options
    
    #--
    # Initialization and setup
    #++
    
    # = Connecting to the Server
    # 
    # Creates a new Client object to allow for requests and responses from
    # the specified server.
    # 
    # The +uri+ param contains the URL to the actual server, and should be in
    # the format: "http://localhost:3801" or "http://app.domain.com:3401/"
    # 
    # == Server Connections
    # 
    # Connecting only occurs at the actual event that a request is performed,
    # so there is no need to worry about closing connections or managing
    # connections in general other than good object housecleaning. (Be nice
    # to your Garbage Collector.)
    # 
    # == Usage
    # 
    # You can either provide a block to perform all of your requests and
    # processing inside of or you can simply accept the object in response
    # and call your request methods off of the returned object.
    # 
    # Alternatively, you could do both.
    # 
    # An example of creating and using a Simple client:
    # 
    #   class Simple < Halcyon::Client
    #     def greet(name)
    #       get("/hello/#{name}")
    #     end
    #   end
    #   Simple.new('http://localhost:3801') do |s|
    #     puts s.greet("Johnny").inspect
    #   end
    # 
    # This should effectively call +inspect+ on a response hash similar to
    # this:
    # 
    #   {:status => 200, :body => 'Hello Johnny'}
    # 
    # Alternatively, you could perform the same with the following:
    # 
    #   s = Simple.new('http://localhost:3801')
    #   puts s.greet("Johnny").inspect
    # 
    # This should generate the exact same outcome as the previous example,
    # except that it is not executed in a block.
    # 
    # The differences are purely semantic and of personal taste.
    # 
    def initialize(uri, headers = {})
      self.uri = URI.parse(uri)
      self.headers = headers
      self.options = DEFAULT_OPTIONS
      if block_given?
        yield self
      end
    end
    
    # Sets the option to raise exceptions when the response from the server is
    # not a +200+ response.
    # 
    def raise_exceptions!(setting = true)
      self.options[:raise_exceptions] = setting
    end
    
    # Sets the option to encode the POST body as +application/json+ compatible.
    # 
    def encode_post_body_as_json!(setting = true)
      if self.options[:encode_post_body_as_json] = setting
        set_content_type "application/json"
      else
        set_content_type "application/x-www-form-urlencoded"
      end
    end
    
    #--
    # Request Handling
    #++
    
    # Performs a GET request on the URI specified.
    # 
    def get(uri, headers={})
      req = Net::HTTP::Get.new(uri)
      request(req, headers)
    end
    
    # Performs a POST request on the URI specified.
    # 
    def post(uri, data = {}, headers={})
      req = Net::HTTP::Post.new(uri)
      req.body = format_body(data)
      request(req, headers)
    end
    
    # Performs a DELETE request on the URI specified.
    # 
    def delete(uri, headers={})
      req = Net::HTTP::Delete.new(uri)
      request(req, headers)
    end
    
    # Performs a PUT request on the URI specified.
    # 
    def put(uri, data = {}, headers={})
      req = Net::HTTP::Put.new(uri)
      req.body = format_body(data)
      request(req, headers)
    end
    
    private
    
    # Performs an arbitrary HTTP request, receive the response, parse it with
    # JSON, and return it to the caller. This is a private method because the
    # user/developer should be quite satisfied with the +get+, +post+, +put+,
    # and +delete+ methods.
    # 
    # == Request Failures
    # 
    # If the server responds with any kind of failure (anything with a status
    # that isn't 200), Halcyon will in turn raise the respective exception
    # (defined in Halcyon::Exceptions) which all inherit from
    # +Halcyon::Exceptions+. It is up to the client to handle these
    # exceptions specifically.
    # 
    def request(req, headers={})
      # set default headers
      req["User-Agent"] = USER_AGENT
      req["Accept"] = ACCEPT
      req["Content-Type"] = CONTENT_TYPE unless req.body.nil?
      req["Content-Length"] = req.body unless req.body.nil?
      
      # apply provided headers
      self.headers.merge(headers).each do |(header, value)|
        req[header] = value
      end
      
      # prepare and send HTTP/S request
      serv = Net::HTTP.new(self.uri.host, self.uri.port)
      prepare_server(serv) if private_methods.include?('prepare_server')
      res = serv.start { |http| http.request(req) }
      
      # parse response
      # unescape just in case any problematic characters were POSTed through
      body = JSON.parse(Rack::Utils.unescape(res.body)).to_mash
      
      # handle non-successes
      if self.options[:raise_exceptions] && !res.kind_of?(Net::HTTPSuccess)
        raise self.class.const_get(Exceptions::HTTP_STATUS_CODES[body[:status]].tr(' ', '_').camel_case.gsub(/( |\-)/,'')).new
      end
      
      # return response
      body
    rescue Halcyon::Exceptions::Base => e
      # log exception if logger is in place
      raise
    end
    
    # Formats the data of a POST or PUT request (the body) into an acceptable
    # format according to Net::HTTP for sending through as a Hash.
    # 
    def format_body(data)
      data = {:body => data} unless data.is_a? Hash
      case CONTENT_TYPE
      when "application/x-www-form-urlencoded"
        Rack::Utils.build_query(data)
      when "application/json"
        data.to_json
      else
        raise ArgumentError.new("Unsupported Content-Type for POST body: #{CONTENT_TYPE}")
      end
    end
    
    # Sets the +CONTENT_TYPE+ to the appropriate type.
    # 
    def set_content_type(content_type)
      self.class.send(:remove_const, :CONTENT_TYPE)
      self.class.const_set(:CONTENT_TYPE, content_type.freeze)
    end
    
  end
end

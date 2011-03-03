module RubyFPS::API
  class Base < RubyFPS::Model
    def self.requires(*fields)
      # TODO: save requiredness
    end

    def valid?
      # check required fields
      # check enumerated fields
      true
    end

    def submit
      raise 'API request is invalid' unless valid?

      params = self.to_hash.merge(
        'Action' => self.class.to_s.split('::').last,
        'AWSAccessKeyId' => RubyFPS.access_key,
        'Version' => RubyFPS::API_VERSION,
        'Timestamp' => Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ')
      )

      params['SignatureVersion'] = 2
      params['SignatureMethod'] = 'HmacSHA256'
      params['Signature'] = RubyFPS.signature(RubyFPS.api_endpoint, params)

      run(RubyFPS.api_endpoint + '?' + RubyFPS.query_string(params))
    end

    class BaseResponse < RubyFPS::Model
      attr_accessor :request_id

      def self.from_xml(xml)
        hash = MultiXml.parse(xml)
        response_key = hash.keys.find{|k| k.match(/Response$/)}
        new(hash[response_key])
      end

      def initialize(hash)
        assign(hash['ResponseMetadata'])
        result_key = hash.keys.find{|k| k.match(/Result$/)}
        assign(hash[result_key]) if hash[result_key] # not all APIs have a result object
      end
    end

    protected
    
    def run(url)
      begin
        response = RestClient.get(url)
        self.class::Response.from_xml(response.body)
      rescue RestClient::BadRequest, RestClient::Unauthorized, RestClient::Forbidden => e
        RubyFPS::API::ErrorResponse.from_xml(e.response.body)
      end
    end

    def to_hash
      (instance_variables - ['@mocha']).inject({}) do |hash, iname|
        name = iname[1..-1]
        val  = send(name)
        hash.merge(name.camelcase => (val.respond_to? :to_hash) ? val.to_hash : val)
      end
    end
  end
end
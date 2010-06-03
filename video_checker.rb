require 'uri'
require 'active_support'

module VideoChecker    
  
  class ParseError < RuntimeError 
    attr_reader :type_code, :url
    def initialize(type_code, url)
      @type_code = type_code
      @url = url
    end

    def message
      "ParseError(#{type_code})"
    end
  end

  class Checker 
    attr_reader :logger
    def initialize(log_out = STDOUT)
      @logger = Logger.new(log_out)
      @logger.level = Logger::INFO
      $LOGGER = @logger
    end

    def check_urls(urls)
    	result = {}
      urls.each_with_index do|url, index|
      	puts "[#{index}] #{url}"
        begin 
        	r = check_url(url)
          result[url] =  r
          logger.info "[result #{r ? "ok" : "bk"}]#{url}"
        rescue RuntimeError => e
          logger.error("[err]#{url}, #{e.message}")
        end
      end
      result
    end

    def check_url(url)
      site = SiteBase.create(url, logger) 
      site.check_url
      site.parse_id
      site.execute
    end
  end

  class SiteBase
    ERROR_URL = "ERROR_URL_NOT_VALID"
    ERROR_URL_ARG = "ERROR_URL_ARG"

    def self.create(url, logger)
      host = URI.parse(url).host
      result = if host =~ /youku/
        Youku.new(url)
      elsif host =~ /56/
        The56.new(url)
      elsif host =~ /tudou/
        Tudou.new(url)
      else
        raise ParseError.new("HOST", url)
      end
      result.logger = logger
      result

    end

    attr_reader :url
    attr_accessor :logger

    def initialize(url)
      @url = url
    end

    def curl(cmd, cmd2=nil)
    	cmd = "curl #{cmd} 2>/dev/null #{cmd2}"
      logger.debug("\t#{cmd}")
      `#{cmd}`
    end

    def check_url
      code = curl "-o /dev/null  -w '%{http_code}' -IL #{url}"
      result = code.strip.to_i
      result >= 200 && result<300
    end

    def parse_id
      @id||= do_parse_id
    end
  end

  class Youku < SiteBase
    ID_PATTEN         = /sid\/(\w+)/
    MUST_HAVE_PATTEN  = /^\{"data"/
    ERROR_PATTEN      = /"tt":"0","error":/

    def execute
      out = curl "http://v.youku.com/player/getPlayList/VideoIDS/#{parse_id}"  
      raise ParseError.new("must_have", url) if !(out =~ MUST_HAVE_PATTEN)

      if out =~ ERROR_PATTEN
        return false
      else
        return true
      end
    end

    def do_parse_id
      url =~ ID_PATTEN
      id = $1
      raise ParseError.new(ERROR_URL_ARG, url) if id.blank?
      id
    end

  end

  class The56 < SiteBase

    def execute
      out = curl "http://vxml.56.com/json/#{parse_id}/?src=out"
      return true if out =~ /^\{"info"/
    end

    def do_parse_id
      url =~ /(\w+)\.\w+$/
      id = $1
      raise ParseError.new(ERROR_URL, url) if id.nil?||id.length<3
      id.split("_").last
    end

  end

  class Tudou < SiteBase
    def execute
      result = curl  "http://www.tudou.com/programs/view/ppvvv.action?d=#{parse_id}"
      return true if result.length>5 
    end

    def do_parse_id
      out = curl "-I #{url} ", "|grep ^Location"
      out=~/\?iid=(\d+)&snap_pic/
      id = $1.to_a
      raise ParseError.new(ERROR_URL, url) if id ==0 
      id
    end
  end
end

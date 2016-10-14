require 'http_anomaly_notifier/version'
require 'http_anomaly_notifier/cli'
require 'net/http'
require 'yaml'
require 'pry'

module HttpAnomalyNotifier
  class Cron
    BEGIN_PHRASE = '### begin http_anomaly_notifier gem monitoring'
    END_PHRASE = '### end http_anomaly_notifier gem monitoring'

    class << self
      def register(file)
        crontab = `crontab -l`.split("\n")
        monitoring_line = false
        new_crontab = []
        crontab.each do |line|
          monitoring_line = true if line == BEGIN_PHRASE
          new_crontab << line unless monitoring_line
          monitoring_line = false if line == END_PHRASE
        end
        new_crontab << '' if new_crontab.size.positive? && new_crontab.last != ''
        new_crontab << BEGIN_PHRASE
        config = YAML.load_file(file)
        config.each do |name, param|
          new_crontab << "#{param['cron']} bundle exec monitor --file=#{file} --name=#{name}"
        end
        new_crontab << END_PHRASE
        `crontab -r`
        `crontab -l | { cat; echo "#{new_crontab.join("\n")}"; } | crontab -`

        results = config.map do |c|
          register c
          "#{c['url']}"
        end
        puts "monitorings ...\n#{results.join("\n")}"
      end
    end
  end

  class HTTP
    def initialize(file:, name:)
      config = YAML.load_file(file)["#{name}"]
      @url = config['url']
      @basic_auth_user = config['basic_auth'].first unless config['basic_auth'].nil?
      @basic_auth_password = config['basic_auth'].last unless config['basic_auth'].nil?
    end

    def request
      req = Net::HTTP::Get.new(@url.path)
      req.basic_auth @basic_auth_user, @basic_auth_password if @basic_auth_user && @basic_auth_password
      res = Net::HTTP.new(@url.host, @url.port).start { |http| http.request(req) }
      res.is_a? Net::HTTPOK
    end
  end

  class Notification
    def initialize(file:, name:)
      config = YAML.load_file(file)[name]
      @chatwork_room_id = config['chatwork_room_id']
      @chatwork_auth_token = config['chatwork_auth_token']
      @body = config['body']
    end

    def post_message
      if @chatwork_room_id && @chatwork_auth_token
        api = URI.parse "https://api.chatwork.com/v1/rooms/#{@chatwork_room_id}/messages"
        api_req = Net::HTTP::Post.new(api.path)
        api_req['X-ChatWorkToken'] = @chatwork_auth_token
        api_req.set_form_data body: @body
        Net::HTTP.start(api.host, api.port, use_ssl: true) { |http| http.request(api_req) }
      end
    end
  end
end

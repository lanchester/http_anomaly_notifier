# coding: utf-8

require 'thor'
require './lib/http_anomaly_notifier'

module HttpAnomalyNotifier
  class CLI < Thor
    desc "monitor FILE", "register monitoring with FILE"
    def register_monitoring(file)
      HttpAnomalyNotifier::Cron.register file
    end

    desc "monitor URL", "start monitoring with URL"
    option :file, type: :string
    option :name, type: :string
    option :test, type: :boolean, default: false
    def monitor
      if options[:test]
        return HttpAnomalyNotifier::Notification.new(file: options[:file], name: options[:name]).post_message
      end
      unless HttpAnomalyNotifier::HTTP.new(file: options[:file], name: options[:name]).request
        HttpAnomalyNotifier::Notification.new(file: options[:file], name: options[:name]).post_message
      end
    end
  end
end

require 'yaml'

module Daemon
  module Config
    CONFIG_FILE = 'config/config.yml'

    def self.load
      @config ||= Daemon::Utils.symbolize_hash( YAML.load_file(CONFIG_FILE) )
    end

    def self.load!
      @config = Daemon::Utils.symbolize_hash( YAML.load_file(CONFIG_FILE) )
    end

    def self.env
      ENV['DAEMON_ENV'] || 'DEV'
    end

    def self.env_channel
      @config[(env + "_CHANNEL").to_sym]
    end

    def self.method_missing(method_name, *args, &block)
      @config[method_name.to_sym]
    end
  end
end

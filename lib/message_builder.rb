require 'yaml'

module Daemon
  class MessageBuilder
    MESSAGE_FILE = 'config/messages.yml'

    def self.load
      @messages ||= Daemon::Utils.symbolize_hash( YAML.load_file(MESSAGE_FILE) )
      nil
    end

    def self.load!
      @messages = Daemon::Utils.symbolize_hash( YAML.load_file(MESSAGE_FILE) )
      nil
    end

    def self.group_created(link, text = link)
      @messages[:group_created] % { group_link: link, text: text }
    end

    def self.unknown_server(server)
      @messages[:unknown_server] % { server: server }
    end

    def self.invalid_command
      @messages[:invalid_command]
    end

    def self.greet
      @messages[:greetings].sample
    end

    def self.user_not_found(username)
      @messages[:user_not_found] % { user: username }
    end

    def self.found_user(username, channel, url)
      @messages[:user_found] % { user: username, channel: channel, url: url }
    end

    def self.method_missing(method_name, *args, &block)
      @messages[method_name.to_sym]
    end
  end
end

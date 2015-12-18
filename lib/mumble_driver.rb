require 'mumble-ruby'

module Daemobot
  class MumbleDriver
    MUMBLE_URL_PROTOCOL = 'mumble://'

    def initialize
      @config = Daemobot::Config.load
      @mumble = Mumble::Client.new(@config[:address]) do |conf|
        conf.username = @config[:username]
      end
    end

    def connect
      @mumble.connect
      @mumble.on_connected { init_configs }
    end

    def disconnect
      @mumble.disconnect
    end

    def current_channel
      @mumble.me.current_channel.channel_id
    end

    def text_current_channel(msg)
      text_channel current_channel, msg
    end

    def text_channel(channel_id, msg)
      begin
        @mumble.text_channel channel_id, msg
      rescue Mumble::ChannelNotFound
        # If the channel wasn't found, perhaps a user removed it
        # Can happen with temporary channels
        # Instead of ignoring, just text the current channel
        # Like, whatever
        text_current_channel(msg)
      end
    end

    def text_user(actor_id, msg)
      @mumble.text_user actor_id, msg
    end

    def on_text_message(&block)
      @mumble.on_text_message(&block)
    end

    def reply(data, msg)
      # If the messager was sent to the channel
      # Reply to the channel where the author is at
      # Otherwise, send a PM to the author
      if data.channel_id
        # yes, by session, using actor id. Don't ask...
        origin = find_user_by_session(data.actor).channel_id
        text_channel origin, msg
      else
        text_user data.actor, msg
      end
    end

    def find_user(session_id)
      begin
        find_user_by_session(session_id).name
      rescue Mumble::UserNotFound
        # If user not found, return nil
        nil
      end
    end

    def move_user(name, channel)
      begin
        @mumble.move_user name, channel
      rescue Mumble::ChannelNotFound
        # We don't have an API call to check if the channel exists
        # So we should just ignore this error when caught
      rescue Mumble::UserNotFound
        # If someone mistyped a name, ignore that user
      end
    end

    def join_channel(channel)
      begin
        @mumble.join_channel channel
      rescue Mumble::ChannelNotFound
        # We don't have an API call to check if the channel exists
        # So we should just ignore this error when caught
      rescue Mumble::UserNotFound
        # If someone mistyped a name, ignore that user
      end
    end

    def find_user_channel(username)
      begin
        user = find_user_ci username
        return nil if user.nil?
        channel_id = user.channel_id
        channel = find_channel_by_id(channel_id)
        { username: user.name, name: channel.name, url: generate_url(channel) }
      rescue Mumble::UserNotFound
        # If we haven't found a valid user, don't expose the exception API
        # Instead, return nil and let that be the application flow control
        nil
      rescue Mumble::ChannelNotFound
        # Ignore invalid channels
        # .nil? should be a valid method to control the application logic
        nil
      end
    end

    private

    # Case insensitive user search
    def find_user_ci(name)
      @mumble.users.values.find do |u|
        u.name.downcase == name.downcase
      end
    end

    def find_user_by_session(session_id)
      @mumble.users.values.find { |u| u.session == session_id }
    end

    def find_channel_by_id(channel_id)
      @mumble.channels.values.find { |c| c.channel_id == channel_id }
    end

    def generate_url(channel)
      body = recursive_url_generator(channel, []).join('/')
      MUMBLE_URL_PROTOCOL + Daemobot::Config.address + '/' + body
    end

    def recursive_url_generator(channel, accumulator)
      # How I wish this was Elixir or Haskell right now...
      if channel.parent_id.nil?
        accumulator
      else
        accumulator.unshift channel.name.gsub(' ', "%20")
        recursive_url_generator(channel.parent, accumulator)
      end
    end

    def init_configs
      @mumble.me.mute
      @mumble.me.deafen
      @mumble.set_comment(Data.help || MessageBuilder.no_help_file)
      @mumble.join_channel(Daemobot::Config.env_channel)
    end
  end
end

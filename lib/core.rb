require 'pry'
module Daemobot
  class Core
    TEXT_CALLBACKS = {
      group: "private_group",
      pubgroup: "public_group",
      hi: "say_hi",
      reload: "reload",
      move: "move",
      join: "join",
      find: "find",
      setgreet: "set_greet",
      greet: "greet"
    }

    def initialize
      @tagpro = TagPro.new
      @mumble = MumbleDriver.new
    end

    def init
      @mumble.connect
      register_callbacks
    end

    def terminate
      @mumble.disconnect
    end

    def private_group(data)
      reply = validate_command("group", data, nr_args: 1) do |args|
        @tagpro.create_group(args.first)
      end
      @mumble.reply(data, reply)
    end

    def public_group(data)
      reply = validate_command("pubgroup", data, nr_args: 1) do |args|
        @tagpro.create_group(args.first, publ: true)
      end
      @mumble.reply(data, reply)
    end

    def say_hi(data)
      reply = validate_command("hi", data, nr_args: 0) do |args|
        MessageBuilder.greet
      end
      @mumble.reply(data, reply)
    end

    def move(data)
      validate_command("move", data, sep: '\n', mod: true) do |args|
        move_users(args)
      end
    end

    def join(data)
      validate_command("join", data, sep: '\n', nr_args: 1, mod: true) do |args|
        @mumble.join_channel args.first.strip
      end
    end

    def find(data)
      validate_command('find', data, nr_args: 1, sep: '\n') do |args|
        user = args.first
        channel = @mumble.find_user_channel user
        reply = channel.nil? ? MessageBuilder.user_not_found(user) :
          MessageBuilder.found_user(channel[:username], channel[:name], channel[:url])
        @mumble.reply(data, reply)
      end
    end

    def reload(data)
      validate_command("reload", data, nr_args: 0, mod: true) do
        Config.load!
        MessageBuilder.load!
      end
    end

    def set_greet(data)
      validate_command('setgreet', data, sep: '\n') do |args|
        username = @mumble.find_user data.actor
        Data.add_greet username, args.first
        @mumble.reply(data, MessageBuilder.greet_set(username))
      end
    end

    def greet(data)
      validate_command('greet', data, nr_args: 0) do |args|
        user = @mumble.find_user data.actor
        reply = Data.greet(user) || MessageBuilder.no_greet(user)
        @mumble.reply(data, reply)
      end
    end

  private

    def register_callbacks
      TEXT_CALLBACKS.each do |cmd, cb|
        @mumble.on_text_message do |data|
          send(cb, data) if data.message =~ /^!#{cmd.to_s}/
        end
      end
    end

    def validate_command(cmd, data, nr_args: nil, sep: ' ',  mod: false, &block)
      match = data.message.match(/^!#{cmd}(.*)?/)
      if mod && !is_mod?(data.actor)
        MessageBuilder.no_permissions
      elsif match
        validate_args(match.captures, nr_args: nr_args, sep: sep, &block)
      else
        MessageBuilder.invalid_command
      end
    end

    def validate_args(captures, nr_args: nil, sep: ' ')
      args = parse_args(captures, sep)
      if nr_args.nil? || args.length == nr_args
        yield args.map(&:strip)
      else
        MessageBuilder.insuficient_arguments
      end
    end

    def parse_args(unparsed_args, sep)
      if unparsed_args.first
        unparsed_args.first.split(sep)
      else
        []
      end
    end

    def is_mod?(session_id)
      name = @mumble.find_user(session_id)
      Config.mods.include? name
    end

    def move_users(args)
      args.each do |user_set|
        move_user_set(user_set)
      end
    end

    def move_user_set(set)
      args = set.split(':')
      return if args.length != 2
      channel = args.first.strip
      users = args[1].split(',')
      return if users.length == 0
      users.each do |u|
        @mumble.move_user u.strip, channel
      end
    end
  end
end

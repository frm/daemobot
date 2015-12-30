module Daemobot
  class Core
    TEXT_CALLBACKS = {
      players: "server_stats",
      group: "private_group",
      pubgroup: "public_group",
      hi: "say_hi",
      reload: "reload",
      move: "move",
      join: "join",
      find: "find",
      setgreet: "set_greet",
      greet: "greet",
      help: "print_help",
      stream: "stream",
      setstream: "set_stream",
      resetstream: "reset_stream",
      bubble: "bubble",
      rekt: "rekt",
      wut: "wut"
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

    def server_stats(data)
      reply = validate_command("players", data, nr_args: nil) do |args|
        @tagpro.server_stats(args.first || Config.default_server)
      end
      @mumble.reply(data, reply)
    end

    def private_group(data)
      reply = validate_command("group", data, nr_args: nil) do |args|
        @tagpro.create_group(args.first || Config.default_server)
      end
      @mumble.reply(data, reply)
    end

    def public_group(data)
      reply = validate_command("pubgroup", data, nr_args: nil) do |args|
        @tagpro.create_group(args.first || Config.default_server, publ: true, name: args[1..-1].join(" ") || "")
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
      validate_command("move", data, sep: "<br />", mod: true) do |args|
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

    def rekt(data)
      validate_command('rekt', data, nr_args: 0, sep: '\n') do |args|
        @mumble.reply(data, bubblize("R E K T") )
      end
    end

    def bubble(data)
      validate_command('bubble', data, sep: '\n') do |args|
        @mumble.reply(data, bubblize(args.first))
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

    def print_help(data)
      validate_command('help', data, nr_args: 0) do
        reply = Data.help || MessageBuilder.no_help_file
        @mumble.reply(data, reply)
      end
    end

    def set_stream(data)
      validate_command('setstream', data, nr_args: 1, mod: true, sep: '\n') do |args|
        set = Data.set_stream args.first
        reply = set ? MessageBuilder.stream_set : MessageBuilder.invalid_stream
        @mumble.reply(data, reply)
      end
    end

    def reset_stream(data)
      validate_command('resetstream', data, nr_args: 0, mod: true) do
        Data.reset_stream
        @mumble.reply(data, MessageBuilder.stream_reset)
      end
    end

    def stream(data)
      validate_command('stream', data, nr_args: 0) do
        reply = Data.stream || MessageBuilder.no_stream
        @mumble.reply(data, reply)
      end
    end

    def wut(data)
      validate_command('wut', data, nr_args: 0) do
        @mumble.reply(data, MessageBuilder.wut)
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
      if banned?(data.actor)
        ban_action(data.actor)
      elsif mod && !is_mod?(data.actor)
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
        yield args.map{ |s| s.strip.gsub('&quot;', '') }
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

    def banned?(session_id)
      name = @mumble.find_user(session_id)
      Config.bans.include? name
    end

    def ban_action(session_id)
      name = @mumble.find_user(session_id)
      @mumble.move_user name, Config.ban_channel
    end

    def bubblize(msg)
      msg.tr('A-Za-z1-90', 'Ⓐ-Ⓩⓐ-ⓩ①-⑨⓪')
    end

    def move_users(args)
      args = args.first.split("<br/>") if args.length < 2
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

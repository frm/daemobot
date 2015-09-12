module Daemon
  module Bootstrap
    def self.run
      Daemon::Config.load
      Daemon::MessageBuilder.load
    end
  end
end

module Daemobot
  module Bootstrap
    def self.run
      Daemobot::Config.load
      Daemobot::MessageBuilder.load
    end
  end
end

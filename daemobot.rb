Dir[File.dirname(__FILE__) + '/lib/*.rb'].each {|file| require file }

module Daemobot
  class App
    def initialize
      Daemobot::Bootstrap.run
      @core = Daemobot::Core.new
    end

    def run
      @core.init

      Signal.trap('INT') do
        @core.terminate
        puts "Bye bye..."
        exit
      end

      sleep
    end
  end
end

Daemobot::App.new.run if __FILE__ == $0

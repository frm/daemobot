module Daemobot
  module Data
    def self.add_greet(username, greet)
      Dir.mkdir(Config.data_folder) unless Dir.exist?(Config.data_folder)

      File.open(filename(username), 'w') do |f|
        f.write greet
      end
    end


    def self.greet(username)
      read_or_nil(filename username)
    end

    def self.help
      read_or_nil Config.help_file
    end

    private

    def self.filename(username)
      "data/#{username}.txt"
    end

    def self.read_or_nil(filename)
      File.exists?(filename) ? File.read(filename) : nil
    end
  end
end

module Daemobot
  module Data
    def self.add_greet(username, greet)
      Dir.mkdir(Config.data_folder) unless Dir.exist?(Config.data_folder)

      File.open(filename(username), 'w') do |f|
        f.write greet
      end
    end


    def self.greet(username)
      file = filename username
      File.exists?(file) ? File.read(file) : nil
    end

    private

    def self.filename(username)
      "data/#{username}.txt"
    end
  end
end

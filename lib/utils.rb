module Daemobot
  module Utils
    def self.symbolize_hash(hash)
      if hash.is_a? Hash
        hash.inject({}) do |res, (key, value)|
          new_key = (key.is_a? String) ? key.to_sym : key
          new_value = (value.is_a? Hash) ? symbolize_hash(value) : value
          res[new_key] = new_value
          res
        end
      elsif hash.is_a? Array
        hash.inject([]) do |res, value|
          res << ((value.is_a? Hash) ? symbolize_hash(value) : value)
          res
        end
      end
    end
  end
end

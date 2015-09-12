module Daemobot
  module Utils
    def self.symbolize_hash(hash)
      hash.inject({}) do |res, (key, value)|
        new_key = (key.is_a? String) ? key.to_sym : key
        new_value = (value.is_a? Hash) ? symbolize_hash(value) : value
        res[new_key] = new_value
        res
      end
    end
  end
end

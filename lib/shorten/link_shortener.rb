Java.import('java.security.MessageDigest')

require 'securerandom'

module Shorten
  # A ShortLink represents the forward and backward lookups for a
  # shortened URL mapped to a random base62-ish string.
  Shorten::ShortLink = Struct.new(:shortened_url, :url, :short_code, :hash)

  # Bag of methods for handling the business of shortening links
  class Shorten::LinkShortener
    BASE62_DICTIONARY = (0..9).to_a + ('A'..'Z').to_a + ('a' .. 'z').to_a

    def self.shorten(url, base_url)
      short_code = self.short_code
      short_url = url_for(short_code, base_url)
      return ShortLink.new(short_url, url, short_code, self.hash(url))
    end

    def self.shorten_with_existing_code(url, base_url, short_code)
      short_url = url_for(short_code, base_url)
      return ShortLink.new(short_url, url, short_code, self.hash(url))
    end

    def self.short_code
      bytes = SecureRandom.random_bytes(12)
      squashed = bytes.bytes.map { |b| BASE62_DICTIONARY[b % 62] }.join
    end

    def self.hash(url)
      bytes = MessageDigest.getInstance('MD5').digest(url.bytes).to_a
      bytes.pack('c*').unpack('H*').first
    end

    def self.url_for(short_code, base_url)
      "#{base_url}/#{short_code}"
    end
  end
end

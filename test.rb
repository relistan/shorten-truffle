#!/usr/bin/env truffleruby

# TruffleRuby demo running sketch intersection

#Java.import('org.apache.datasketches.theta.UpdateSketch')
#Java.import('org.apache.datasketches.theta.Intersection')
#Java.import('org.apache.datasketches.theta.SetOperation')
Java.import('spark.Spark')
Java.import('java.security.MessageDigest')
Java.import('com.datastax.oss.driver.api.core.CqlSession')
Java.import('java.net.InetSocketAddress')

#sketch = UpdateSketch.builder().setNominalEntries(8192).build()
#1.upto(100_000) { |i| sketch.update(i.to_s) }
#
#sketch2 = UpdateSketch.builder().setNominalEntries(8192).build()
#50_000.upto(100_000) { |i| sketch2.update(i.to_s) }
#
#intersection = SetOperation.builder().buildIntersection()
#result = intersection.intersect(sketch, sketch2)
#
#puts sketch.toString()
#puts sketch2.toString()
#puts result.toString()

require 'json'
require 'securerandom'
require 'uri'

# A ShortLink represents the forward and backward lookups for a
# shortened URL mapped to a random base62-ish string.
ShortLink = Struct.new(:short_code, :sum)

class LinkShortener
  BASE62_DICTIONARY = (0..9).to_a + ('A'..'Z').to_a + ('a' .. 'z').to_a
  def self.shorten(url)
    return ShortLink.new(self.short_code, self.hash(url))
  end

  def self.short_code
    bytes = SecureRandom.random_bytes(12)
    squashed = bytes.bytes.map { |b| BASE62_DICTIONARY[b % 62] }.join
  end

  def self.hash(url)
    bytes = MessageDigest.getInstance('MD5').digest(url.bytes).to_a
    bytes.pack('c*').unpack('H*').first
  end
end

puts LinkShortener.shorten('https://relistan.com')

class Server
  def initialize(connection)
    @db = connection
  end

  def spark
    Spark.get('/shorten', ->(req, res) do
      # Get and validate the param
      url = req.queryParams('url')
      begin
        URI(url)
      rescue URI::InvalidURIError
        # error result
      end

      shortened = LinkShortener.shorten(url)
      { url: url, short_code: shortened.short_code }.to_json
    end)
  end
end

def db_connect(node, port, dataCenter)
  builder = CqlSession.builder();
  builder.addContactPoint(InetSocketAddress.new(node, port));
  builder.withLocalDatacenter(dataCenter);

  builder.build();
end

connection = db_connect('127.0.0.1', 9042, 'datacenter1')
server = Server.new(connection)
server.spark
Thread.current.join

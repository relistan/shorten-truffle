#!/usr/bin/env truffleruby

Java.import('spark.Spark')
Java.import('java.security.MessageDigest')
Java.import('java.time.Instant')
Java.import('com.datastax.oss.driver.api.core.CqlSession')
Java.import('com.datastax.oss.driver.api.querybuilder.QueryBuilder')
Java.import('java.net.InetSocketAddress')

require 'json'
require 'securerandom'
require 'uri'

# A ShortLink represents the forward and backward lookups for a
# shortened URL mapped to a random base62-ish string.
ShortLink = Struct.new(:shortened_url, :url, :short_code, :sum)

class LinkShortener
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

class CassandraStore
  def initialize(node, port, data_center, keyspace)
    @db = connect(node, port, data_center, keyspace)
    prepare_queries
  end

  def insert_short_link(shortened)
    created_at = Instant.now

    forward_stmt = @forward_insert.bind()
        .setString(0, shortened.short_code)
        .setString(1, shortened.url)
        .setInstant(2, created_at)

    @db.execute(forward_stmt)

    hash = LinkShortener.hash(shortened.url)

    reverse_stmt = @reverse_insert.bind()
        .setString(0, hash)
        .setString(1, shortened.short_code)
        .setInstant(2, created_at)

    @db.execute(reverse_stmt)
  end

  def get_link_by_code(code)
    forward_stmt = @forward_lookup
      .bind()
      .setString(0, code)

    # Java null doesn't coerce properly for &. syntax
    (@db.execute(forward_stmt).one || nil)
      &.getString('url') || ''
  end

  def get_link_by_hash(hash)
    reverse_stmt = @reverse_lookup
      .bind()
      .setString(0, hash)

    # Java null doesn't coerce properly for &. syntax
    (@db.execute(reverse_stmt).one || nil)
      &.getString('code') || ''
  end

  private
    def connect(node, port, data_center, keyspace)
      CqlSession.builder()
        .addContactPoint(InetSocketAddress.new(node, port))
        .withLocalDatacenter(data_center)
        .withKeyspace(keyspace)
        .build()
    end

    def prepare_queries
      @forward_insert = @db.prepare(
        QueryBuilder.insertInto('forward')
          .value('code', QueryBuilder.bindMarker)
          .value('url', QueryBuilder.bindMarker)
          .value('created_at', QueryBuilder.bindMarker)
          .build()
      )

      @reverse_insert = @db.prepare(
        QueryBuilder.insertInto('reverse')
          .value('hash', QueryBuilder.bindMarker)
          .value('code', QueryBuilder.bindMarker)
          .value('created_at', QueryBuilder.bindMarker)
          .build()
      )

      @forward_lookup = @db.prepare(
        QueryBuilder.selectFrom('forward')
          .column('url')
          .whereColumn('code')
          .isEqualTo(QueryBuilder.bindMarker())
          .build()
      )

      @reverse_lookup = @db.prepare(
        QueryBuilder.selectFrom('reverse')
          .column('code')
          .whereColumn('hash')
          .isEqualTo(QueryBuilder.bindMarker())
          .build()
      )
    end
end

class Server
  def initialize(store, base_url)
    @store = store
    @base_url = base_url
  end

  def serve
    Spark.get('/shorten', ->(req, res) { handle_get_shorten(req, res) })
    Spark.get('/lookup', ->(req, res) { handle_get_lookup(req, res) })
    Spark.get('/r/:code', ->(req, res) { handle_get_redirect(req, res) })
  end

  def handle_get_shorten(req, res)
    url = req.queryParams('url')
    res.header('content-type', 'application/json')

    unless valid_url?(url)
      res.status(400)
      return { error: 'invalid URL supplied' }.to_json
    end

    hash = LinkShortener.hash(url)

    # If we already have it, return it. Otherwise generate/insert it.
    code = @store.get_link_by_hash(hash)
    shortened = if code != ''
      LinkShortener.shorten_with_existing_code(url, @base_url, code)
    else
      LinkShortener.shorten(url, @base_url).tap do |s|
        @store.insert_short_link(s)
      end
    end

    { data: shortened.to_h }.to_json
  end

  def handle_get_lookup(req, res)
    code = req.queryParams('code')
    res.header('content-type', 'application/json')

    unless valid_code?(code)
      res.status(400)
      return { error: 'invalid code supplied' }.to_json
    end

    url = @store.get_link_by_code(code)
    shortened = LinkShortener.shorten_with_existing_code(url, @base_url, code)
    { data: shortened.to_h }.to_json
  end

  def handle_get_redirect(req, res)
    code = req.params('code')

    unless valid_code?(code)
      res.status(400)
      res.header('content-type', 'application/json')
      return { error: 'invalid code supplied' }.to_json
    end

    url = @store.get_link_by_code(code)
    res.header('location', url)
    res.status(302)
    ''
  end

  private
    def valid_code?(code)
      code.size == 12 && code =~ /^[0-9A-Za-z]{12}/
    end

    def valid_url?(url)
      # Does it at least parse as a URL?
      begin
        URI(url)
      rescue URI::InvalidURIError
        return false
      end
      true
    end
end

# This is the base to which we'll attach the short_code
BASE_URL = ENV['BASE_URL'] || 'http://localhost:4567/r'

# Where can we reach Cassandra?
CASSANDRA_HOST = ENV['CASSANDRA_HOST'] || '127.0.0.1'
CASSANDRA_PORT = (ENV['CASSANDRA_PORT'] || '9042').to_i

store = CassandraStore.new(CASSANDRA_HOST, CASSANDRA_PORT, 'datacenter1', 'links')
server = Server.new(store, BASE_URL)
server.serve

Thread.current.join

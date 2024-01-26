#!/usr/bin/env truffleruby

Java.import('spark.Spark')

require 'json'
require 'uri'
require_relative 'lib/shorten'

class Server
  def initialize(store:, filter:, base_url:)
    @store = store
    @bloomfilter = filter
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

    hash = Shorten::LinkShortener.hash(url)

    # If we already have it, return it. Otherwise generate/insert it.
    code = if @bloomfilter.mightContain(hash)
      @store.get_link_by_hash(hash)
    else
      ''
    end

    shortened = if code != ''
      Shorten::LinkShortener.shorten_with_existing_code(url, @base_url, code)
    else
      Shorten::LinkShortener.shorten(url, @base_url).tap do |s|
        s.hash = hash # Add the hash we calculated to the ShortLink
        @store.insert_short_link(s)
        @bloomfilter.put(hash)
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
    shortened = Shorten::LinkShortener.shorten_with_existing_code(url, @base_url, code)
    { data: shortened.to_h }.to_json
  end

  def handle_get_redirect(req, res)
    code = req.params('code')
    res.header('content-type', 'application/json')

    unless valid_code?(code)
      res.status(400)
      return { error: 'invalid code supplied' }.to_json
    end

    url = @store.get_link_by_code(code)
    if url == ''
      res.status(404)
      return { error: 'code not found' }.to_json
    end

    res.header('location', url)
    res.status(302)
    ''
  end

  private
    def valid_code?(code)
      code.size == 12 && code =~ /^[0-9A-Za-z]{12}/
    end

    def valid_url?(url)
      return url =~ /^(http|https):\/\/.+$/
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

# Bloom filter settings
BLOOMFILTER_BASE_SIZE = (ENV['BLOOMFILTER_BASE_SIZE'] || '100_000').to_i
BLOOMFILTER_RESIZE_INTERVAL = (ENV['BLOOMFILTER_RESIZE_INTERVAL'] || '10').to_i # seconds
BLOOMFILTER_MAX_LENGTH = (ENV['BLOOMFILTER_MAX_LENGTH'] || '5').to_i

filter = Shorten::ExpandingBloomFilter.new(
  base_size:       BLOOMFILTER_BASE_SIZE,
  resize_interval: BLOOMFILTER_RESIZE_INTERVAL,
  max_length:      BLOOMFILTER_MAX_LENGTH
)

store = Shorten::CassandraStore.new(
  node:     CASSANDRA_HOST,
  port:     CASSANDRA_PORT,
  dc:       'datacenter1',
  keyspace: 'links'
)

Server.new(
  store: store,
  filter: filter,
  base_url: BASE_URL
).serve

Thread.current.join

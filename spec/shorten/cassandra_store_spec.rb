require 'rspec/collection_matchers'
require 'shorten/link_shortener'
require 'shorten/cassandra_store'

describe Shorten::CassandraStore do
  context 'When shortening links' do
    let(:base_url)  { 'http://localhost:4000' }
    let(:url)       { 'https://relistan.com' }
    let(:shortened) { Shorten::LinkShortener.shorten(url, base_url) }
    let(:store)     {
      Shorten::CassandraStore.new(
        node: '127.0.0.1', port: 9042, dc: 'datacenter1', keyspace: 'links',
      )
    }

    it 'inserts and reads back the original URL using the forward code' do
      expect { store.insert_short_link(shortened) }.not_to raise_error

      url_from_db = store.get_link_by_code(shortened.short_code)
      expect(url_from_db).to eq(shortened.url)
    end

    it 'inserts and reads back the short link using the reverse code' do
      expect { store.insert_short_link(shortened) }.not_to raise_error

      code_from_db = store.get_link_by_hash(shortened.hash)
      expect(code_from_db).to eq(shortened.short_code)
    end
  end
end

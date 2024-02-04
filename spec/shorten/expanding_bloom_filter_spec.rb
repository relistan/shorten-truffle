require 'rspec/collection_matchers'
require 'shorten/link_shortener'
require 'shorten/expanding_bloom_filter'

describe Shorten::ExpandingBloomFilter do
  context 'When using the bloom filter' do
    let(:filter) {
      Shorten::ExpandingBloomFilter.new(
        base_size: 5, resize_interval: 1, max_length: 1000
      )
    }

    it 'inserts text entries' do
      expect {
        filter.put('123')
        filter.put('asd')
        filter.put('zxc')
      }.not_to raise_error
    end

    it 'checks for presence of a value' do
      filter.put('123')
      filter.put('asd')
      filter.put('zxc')

      expect(filter.mightContain('123')).to be(true)
      expect(filter.mightContain('yoyo')).to be(false)
    end

    it 'still works when resized' do
      filter.put('123')
      filter.put('asd')
      filter.put('zxc')

      filter.resize

      expect(filter.mightContain('123')).to be(true)
      expect(filter.mightContain('yoyo')).to be(false)
    end
  end
end

require 'rspec/collection_matchers'
require 'shorten/link_shortener'

describe Shorten::LinkShortener do
  context 'When shortening links' do
    let(:base_url)  { 'http://localhost:4000' }
    let(:url)       { 'https://relistan.com' }
    let(:shortened) { Shorten::LinkShortener.shorten(url, base_url) }

    it 'returns a code 12 bytes in length' do
      expect(shortened).to be_a(Shorten::ShortLink)
      expect(shortened.short_code).to have_exactly(12).characters
    end

    it 'includes the original URL' do
      expect(shortened.url).to eq(url)
    end

    it 'includes the full shortened URL' do
      expect(shortened.shortened_url).to eq("#{base_url}/#{shortened.short_code}")
    end

    it 'includes a correct reverse hash' do
      expect(shortened.hash).to have_exactly(32).characters
    end
  end
end

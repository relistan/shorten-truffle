Java.import('com.google.common.base.Charsets')
Java.import('com.google.common.hash.BloomFilter')
Java.import('com.google.common.hash.Funnels')

module Shorten
	# A bloom filter wrapper that keeps a list of filters, each twice as large as
	# the previous and treats them like one filter. This list will grow in length
	# up to BLOOMFILTER_MAX_LENGTH. In theory it could grow unbounded, but growth
	# should taper off heavily.
	class ExpandingBloomFilter
	  def initialize(base_size:, resize_interval:, max_length:)
	    @filters    = [create_filter(base_size)]
	    @last_size  = base_size
      @max_length = max_length

	    Thread.new { maintain_filter(resize_interval, max_length) }
	  end

	  def put(*args)
	    @filters.last.put(*args)
	  end

	  def mightContain(*args)
	    # any? guarantees short-circuit behavior.
	    @filters.any? { |f| f.mightContain(*args) }
	  end

    def resize
	    puts "Adding bloom filter. Total size #{@filters.size}"
	    @last_size *= 2

	    new_filter = create_filter(@last_size)
	    @filters = if @filters.size > @max_length
	      puts 'Dropping oldest bloom filter'
	      @filters[1..-1] << new_filter
	    else
	      @filters << new_filter
	    end
    end

	  private
	    def create_filter(size)
	      BloomFilter.create(
	        Funnels.stringFunnel(Charsets.UTF_8), size, 0.01
	      )
	    end

	    def maintain_filter(resize_interval, max_length)
	      puts 'Filter maintenance plan in action'

	      loop do
	        sleep(resize_interval)

	        # If accuracy is getting bad, we'll have to add one
	        next unless @filters.last.expectedFpp > 0.1 # matches create Fpp

          resize
	      end
	    end
	end
end

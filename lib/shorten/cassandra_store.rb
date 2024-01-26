Java.import('java.net.InetSocketAddress')
Java.import('java.time.Instant')

Java.import('com.datastax.oss.driver.api.core.CqlSession')
Java.import('com.datastax.oss.driver.api.querybuilder.QueryBuilder')

module Shorten
	# Link store backed by Cassandra/Scylladb
	class CassandraStore
	  def initialize(node:, port:, dc:, keyspace:)
	    @db = connect(node, port, dc, keyspace)
	    prepare_queries
	  end

	  def insert_short_link(shortened)
	    created_at = Instant.now

	    forward_stmt = @forward_insert.bind()
	        .setString(0, shortened.short_code)
	        .setString(1, shortened.url)
	        .setInstant(2, created_at)

	    # This one is async, the second is sync. Keeps it from getting
	    # overrun but introduces a little concurrency.
	    @db.executeAsync(forward_stmt)

	    reverse_stmt = @reverse_insert.bind()
	        .setString(0, shortened.hash)
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
end

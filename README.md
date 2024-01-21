A Link Shortener in TruffleRuby
===============================

This is a PoC link shortener implemented in TruffleRuby and backed by Cassandra
or ScyllaDB. It generates 12-digit random shorten codes, and will repetably
generate the same code for the same URL as long as it has not expired.
Expiration is handled by Cassandra TTLs on the records.

This application is written in Ruby but uses the Java libraries for a number of
functions, including the Sinatra-like Spark web framework (and Jetty webserver)
and the Datastax Cassandra driver and query tooling.

Configuration
-------------

This application is configured via environment variables. It supports the following:

 * `BASE_URL` - the base URL from which the server will run. Used to generate
   the correct shortened links. default: `http://localhost:4567/r`
 * `CASSANDRA_HOST` - the IP address/DNS name at which to reach the Cassandra host.
   default: `127.0.0.1`
 * `CASSANDRA_PORT` - the port on which to reach Cassandra. default: `9042`

The default is to run a simple one node Cassadra/ScyllaDB cluster with no replication.
If you were to put this into production, you would want to do better. This, and
the TTL for links, are defined in `schema.cql`.

API
---

The API for this service is quite simple and supports the following endpoints:

### `GET /shorten?url=<url>`

This will return a payload like:
```json
{
   "data" : {
      "short_code" : "tkAZYPaHmSuI",
      "shortened_url" : "http://localhost:4567/r/tkAZYPaHmSuI",
      "sum" : "99999ebcfdb78df077ad2727fd00969f",
      "url" : "https://google.com"
   }
}
```

### `GET /lookup?code=<short_code>`

Response payload is like:

```json
{
   "data" : {
      "short_code" : "aaaaaaaaaaaa",
      "shortened_url" : "http://localhost:4567/r/aaaaaaaaaaaa",
      "sum" : "d41d8cd98f00b204e9800998ecf8427e",
      "url" : ""
   }
}
```

### `GET /r/<short_code>`

This returns no payload and simply sends a 302 redirect to the location stored
for the corresponding short code. On a missing code, an error is returned:

```json
{"error":"code not found"}
```
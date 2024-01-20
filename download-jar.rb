#!/usr/bin/env ruby

# This script accepts a blob of XML on ARGF/stdin like the following, and
# downloads the jar to the current directory.
#
# <dependency>
#   <groupId>com.datastax.cassandra</groupId>
#   <artifactId>cassandra-driver-core</artifactId>
#   <version>3.0.8</version>
#   <classifier>shaded</classifier>
#   <!-- Because the shaded JAR uses the original POM, you still need
#        to exclude this dependency explicitly: -->
#   <exclusions>
#     <exclusion>
#       <groupId>io.netty</groupId>
#       <artifactId>*</artifactId>
#     </exclusion>
#   </exclusions>
# </dependency>

require 'excon'
require 'nokogiri'

BASE_URL = "https://repo1.maven.org/maven2/"

class MavenDependency
  def initialize(xml_str)
    doc = Nokogiri::Slop(xml_str)
    @group_id = doc.dependency.groupId.content
    @artifact_id = doc.dependency.artifactId.content
    @version = doc.dependency.version.content
    @classifier = begin
      doc.dependency.classifier.content
    rescue
      nil
    end
  end

  def download
    puts "Downloading #{url}"
    response = Excon.get(url)
    abort "Failed to download. Status #{response.status}" if response.status != 200

    File.write(filename, response.body)
    puts "Success: #{filename} downloaded"
  end

  private
    def filename
      [@artifact_id, @version, @classifier].compact.join('-') + '.jar'
    end

    def url
      url = (@group_id.split(/\./) + [@artifact_id, @version]).join('/') + '/'
      "#{BASE_URL}#{url}#{filename}"
    end
end

dep = MavenDependency.new(ARGF.read)
dep.download

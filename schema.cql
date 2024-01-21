CREATE KEYSPACE IF NOT EXISTS links WITH REPLICATION = { 'class' : 'SimpleStrategy', 'replication_factor' : 1 };

USE links;

CREATE TABLE IF NOT EXISTS forward ( code text, url text, created_at timestamp, primary key(code)) WITH default_time_to_live = 7776000;

CREATE TABLE IF NOT EXISTS reverse ( hash text, code text, created_at timestamp, primary key(hash)) WITH default_time_to_live = 7776000;




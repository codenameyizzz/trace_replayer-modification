docker compose exec a bash -lc "/opt/cassandra/tools/bin/cassandra-stress write duration=\"${DURATION}s\" \
  -node 127.0.0.1:9042 \
  -schema 'replication(factor=3)' \
  -mode native cql3 \
  -col 'n=FIXED(1)' \
  -rate threads=50"

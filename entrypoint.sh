#!/bin/bash
set -e

# Generate config from environment variables
#envsubst < /kungfuchess/kungFuChess.cnf.template > /kungfuchess/kungFuChess.cnf

# Start KungFuChess
exec morbo KungFuWeb.pl -l "http://0.0.0.0:3000" -w templates/ -w KungFuChess/

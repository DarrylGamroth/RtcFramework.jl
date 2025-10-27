#!/bin/bash

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Set the environment variables
export JULIA_NUM_THREADS="4"
# export JULIA_NUM_GC_THREADS="1"
export JULIA_PROJECT="$SCRIPT_DIR"
export HEARTBEAT_PERIOD_NS=10000000000
export BLOCK_NAME="TestService"
export BLOCK_ID=999
export LOG_LEVEL="Debug"
export GC_LOGGING=false

export CONTROL_PLANE_INTERFACE="127.0.0.1"

export CONTROL_URI="aeron:udp?endpoint=239.192.10.101:40100|interface=${CONTROL_PLANE_INTERFACE}|ttl=1"
export CONTROL_STREAM_ID=10

export STATUS_URI="aeron:udp?endpoint=239.192.10.111:40100|interface=${CONTROL_PLANE_INTERFACE}|ttl=1"
export STATUS_STREAM_ID=100

export CONTROL_FILTER="(All|TestService)"

export SUB_DATA_URI_1="aeron:udp?endpoint=localhost:40123"
export SUB_DATA_STREAM_1=10

export PUB_DATA_URI_1="aeron:udp?endpoint=localhost:40123|term-length=512m"
# export PUB_DATA_URI_1="aeron:ipc"
export PUB_DATA_STREAM_1=12

# export PUB_DATA_URI_2="aeron:udp?endpoint=localhost:40123"
# export PUB_DATA_STREAM_2=13

# Run the Julia script with the local TestService module
cd "$SCRIPT_DIR"
julia --project=. -e "include(\"TestService.jl\"); TestService.main()" "$@"

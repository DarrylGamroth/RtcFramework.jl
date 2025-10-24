"""
    RtcFramework Counter System

Minimal performance counter system using Aeron's native counter allocation for
external observability via AeronStat. Counters are allocated in the MediaDriver's
shared memory and can be monitored by external tools.

# Counter Types
- `TOTAL_DUTY_CYCLES`: Total duty cycles executed (work loop health)
- `TOTAL_WORK_DONE`: Cumulative work units processed (throughput)
- `PROPERTIES_PUBLISHED`: Total property publications (property system activity)

# Design Philosophy
This minimal set tracks application-level metrics that are not provided by Aeron's
native per-stream counters. For transport-level metrics (bytes, messages, backpressure),
use Aeron's subscription/publication counters directly.

# External Observability
Counters are visible in AeronStat with agent identification:
```
1001: 5,455,379,113 - TotalDutyCycles [NodeId=42, Name=TestAgent]
1002:         384 - TotalWorkDone [NodeId=42, Name=TestAgent]
1003:           0 - PropertiesPublished [NodeId=42, Name=TestAgent]
```

Each counter label includes the agent's NodeId and Name for easy identification
when multiple agents share the same MediaDriver.

# Architecture
Counters are allocated through Aeron's CountersManager using type_id ≥ 1000
(reserved for user applications). Each counter has:
- Unique type_id for counter type identification
- Label with agent identification for AeronStat display
- Key buffer containing agent_id and agent_name for programmatic access

# Example
```julia
counters = Counters(aeron_client, node_id, agent_name)
increment_counter!(counters, TOTAL_DUTY_CYCLES)
count = get_counter(counters, TOTAL_DUTY_CYCLES)
```
"""

"""
    CounterId

Enumeration of available performance counters.

Uses 1-based indexing for direct Julia vector access. These map to Aeron
type_id values by adding `BASE_COUNTER_TYPE_ID`.

# Minimal Application-Level Counters
- `TOTAL_DUTY_CYCLES`: Work loop iterations (health/liveness)
- `TOTAL_WORK_DONE`: Accumulated work units (throughput)
- `PROPERTIES_PUBLISHED`: Property publication events (property system activity)

For transport metrics (messages sent/received, bytes, backpressure), use Aeron's
native subscription/publication counters.
"""
@enum CounterId::Int32 begin
    TOTAL_DUTY_CYCLES = 1
    TOTAL_WORK_DONE = 2
    PROPERTIES_PUBLISHED = 3
end

"""
    BASE_COUNTER_TYPE_ID

Base type_id for RtcFramework counters in Aeron's counter system.
User counters must use type_id ≥ 1000 per Aeron convention.
"""
const BASE_COUNTER_TYPE_ID = Int32(1000)

"""
    CounterMetadata

Metadata describing a performance counter.

# Fields
- `id::CounterId`: unique counter identifier (maps to index)
- `type_id::Int32`: Aeron type_id (BASE_COUNTER_TYPE_ID + id)
- `label::String`: short counter name for display in AeronStat
- `description::String`: detailed counter description
"""
struct CounterMetadata
    id::CounterId
    type_id::Int32
    label::String
    description::String
end

"""
    COUNTER_METADATA

Metadata for all defined counters in enumeration order.

Type IDs are automatically calculated as BASE_COUNTER_TYPE_ID + enum_value.
"""
const COUNTER_METADATA = [
    CounterMetadata(TOTAL_DUTY_CYCLES, BASE_COUNTER_TYPE_ID + Int32(TOTAL_DUTY_CYCLES), "TotalDutyCycles", "Total duty cycles executed"),
    CounterMetadata(TOTAL_WORK_DONE, BASE_COUNTER_TYPE_ID + Int32(TOTAL_WORK_DONE), "TotalWorkDone", "Cumulative work units processed"),
    CounterMetadata(PROPERTIES_PUBLISHED, BASE_COUNTER_TYPE_ID + Int32(PROPERTIES_PUBLISHED), "PropertiesPublished", "Total property publications"),
]

"""
    Counters

Immutable container for Aeron performance counters with agent identification.

Stores the vector of allocated Aeron counters along with agent metadata that
is encoded in each counter's key buffer for external observability via AeronStat.

# Fields
- `vec::Vector{Aeron.Counter}`: allocated counters indexed by CounterId
- `agent_id::Int64`: agent's unique node ID
- `agent_name::String`: agent's name for identification in AeronStat

# Notes
The key buffer for each counter contains:
- agent_id (8 bytes): numeric identifier
- agent_name (variable): UTF-8 encoded name string

This allows AeronStat to display counter labels like:
"TotalDutyCycles: NodeId=42 Name=MyAgent"
"""
struct Counters
    vec::Vector{Aeron.Counter}
    agent_id::Int64
    agent_name::String
end

"""
    Counters(client::Aeron.Client, agent_id::Int64, agent_name::String) -> Counters

Allocate all RtcFramework counters in Aeron's shared memory with agent identification.

# Arguments
- `client::Aeron.Client`: Aeron client instance
- `agent_id::Int64`: Unique agent identifier (NodeId)
- `agent_name::String`: Agent name for AeronStat display

# Returns
Counters container with allocated Aeron.Counter instances indexed by CounterId enum.

# Notes
Each counter is allocated with:
- type_id from COUNTER_METADATA
- label from COUNTER_METADATA (e.g., "TotalDutyCycles")
- key buffer containing agent_id and agent_name for identification

The key buffer format is:
- Bytes 0-7: agent_id (Int64, little-endian)
- Bytes 8+: agent_name (UTF-8 string)

This enables AeronStat to display counters with context:
```
1001: 5,455,379,113 - TotalDutyCycles: NodeId=42 Name=TestAgent
1002:         384 - TotalWorkDone: NodeId=42 Name=TestAgent
1003:           0 - PropertiesPublished: NodeId=42 Name=TestAgent
```
"""
function Counters(client::Aeron.Client, agent_id::Int64, agent_name::String)
    vec = Vector{Aeron.Counter}(undef, length(instances(CounterId)))
    
    # Create key buffer with agent ID and name for counter identification
    # Format: [agent_id (8 bytes)] [agent_name (UTF-8 string)]
    name_bytes = codeunits(agent_name)
    key_buffer = Vector{UInt8}(undef, sizeof(Int64) + length(name_bytes))
    
    # Write agent_id (first 8 bytes)
    key_buffer[1:8] .= reinterpret(UInt8, [agent_id])
    
    # Write agent_name (remaining bytes)
    key_buffer[9:end] .= name_bytes
    
    @inbounds for metadata in COUNTER_METADATA
        idx = Int(metadata.id)
        # Construct label with agent identification
        label = "$(metadata.label): NodeId=$agent_id Name=$agent_name"
        vec[idx] = Aeron.add_counter(client, metadata.type_id, key_buffer, label)
    end
    
    return Counters(vec, agent_id, agent_name)
end

"""
    get_counter(counters::Counters, id::CounterId) -> Int64

Get the current value of the specified counter.

# Arguments
- `counters`: Counters container with allocated Aeron counters
- `id`: CounterId enum value

# Returns
Current counter value (atomically loaded)
"""
@inline function get_counter(counters::Counters, id::CounterId)
    @inbounds counters.vec[Int(id)][]
end

"""
    increment_counter!(counters::Counters, id::CounterId, delta::Int=1)

Increment the specified counter by delta (default 1).

# Arguments
- `counters`: Counters container with allocated Aeron counters
- `id`: CounterId enum value
- `delta`: Amount to increment by (default 1)

Performs atomic increment operation with bounds checking elided via @inbounds.
"""
@inline function increment_counter!(counters::Counters, id::CounterId, delta::Int=1)
    @inbounds increment!(counters.vec[Int(id)], delta)
    nothing
end

"""
    set_counter!(counter::Aeron.Counter, value::Int64)

Set an Aeron counter to an explicit value.

Uses Aeron's atomic set operation for thread-safe updates.
"""
@inline function set_counter!(counter::Aeron.Counter, value::Int64)
    counter[] = value
    nothing
end

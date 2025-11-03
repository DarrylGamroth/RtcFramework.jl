"""
    RtcFramework Counter System

Minimal, extensible performance counter system using Aeron's native counter allocation
for external observability via AeronStat. Counters are allocated in the MediaDriver's
shared memory and can be monitored by external tools.

# Design Philosophy
This minimal set tracks application-level metrics that are not provided by Aeron's
native per-stream counters. For transport-level metrics (bytes, messages, backpressure),
use Aeron's subscription/publication counters directly.

# RtcFramework Standard Counters
The framework provides three standard counters:
- `duty_cycles::Aeron.Counter`: Total duty cycles executed (work loop health)
- `work_done::Aeron.Counter`: Cumulative work units processed (throughput)
- `properties_published::Aeron.Counter`: Total property publications

# Extensibility for Downstream Packages
Downstream packages can define their own Counters struct with domain-specific counters.
Use the `add_counter` helper function to handle boilerplate:

```julia
# In your downstream package
struct GenIcamCounters
    frames_captured::Aeron.Counter
    frames_dropped::Aeron.Counter
    exposure_adjustments::Aeron.Counter
end

function GenIcamCounters(client::Aeron.Client, agent_id::Int64, agent_name::String)
    GenIcamCounters(
        add_counter(client, agent_id, agent_name, 2001, "FramesCaptured"),
        add_counter(client, agent_id, agent_name, 2002, "FramesDropped"),
        add_counter(client, agent_id, agent_name, 2003, "ExposureAdjustments")
    )
end

function Base.close(counters::GenIcamCounters)
    close(counters.frames_captured)
    close(counters.frames_dropped)
    close(counters.exposure_adjustments)
end
```

# External Observability
Counters are visible in AeronStat with agent identification:
```
1001: 5,455,379,113 - TotalDutyCycles: NodeId=42 Name=TestAgent
1002:         384 - TotalWorkDone: NodeId=42 Name=TestAgent
1003:           0 - PropertiesPublished: NodeId=42 Name=TestAgent
```

# Architecture
Counters are allocated through Aeron's CountersManager using type_id ≥ 1000
(reserved for user applications). Each counter has:
- Unique type_id for counter type identification
- Label with agent identification for AeronStat display
- Key buffer containing agent_id and agent_name for programmatic access

# Example Usage
```julia
counters = Counters(aeron_client, node_id, agent_name)
Aeron.increment!(counters.duty_cycles)
count = counters.work_done[]
```
"""

"""
    add_counter(client::Aeron.Client, agent_id::Int64, agent_name::String,
                type_id::Int32, label::String) -> Aeron.Counter

Helper function to allocate an Aeron counter with agent identification.

This function handles the boilerplate of creating the key buffer with agent_id
and agent_name, and constructing the full label with agent identification for
AeronStat display.

# Arguments
- `client::Aeron.Client`: Aeron client instance
- `agent_id::Int64`: Unique agent identifier (NodeId)
- `agent_name::String`: Agent name for identification
- `type_id::Int32`: Aeron counter type_id (should be ≥ 1000 for user counters)
- `label::String`: Short counter name (e.g., "FramesCaptured")

# Returns
Allocated `Aeron.Counter` that can be incremented or read.

# Notes
The key buffer format is:
- Bytes 0-7: agent_id (Int64, little-endian)
- Bytes 8+: agent_name (UTF-8 string)

The full label will be: "\$label: NodeId=\$agent_id Name=\$agent_name"

# Example
```julia
frames_counter = add_counter(client, 42, "GenIcam", 2001, "FramesCaptured")
Aeron.increment!(frames_counter)
```
"""
function add_counter(client::Aeron.Client, agent_id::Int64, agent_name::String,
                     type_id::Int32, label::String)
    # Create key buffer with agent ID and name for counter identification
    # Format: [agent_id (8 bytes)] [agent_name (UTF-8 string)]
    name_bytes = codeunits(agent_name)
    key_buffer = Vector{UInt8}(undef, sizeof(Int64) + length(name_bytes))
    
    # Write agent_id (first 8 bytes)
    key_buffer[1:8] .= reinterpret(UInt8, [agent_id])
    
    # Write agent_name (remaining bytes)
    key_buffer[9:end] .= name_bytes
    
    # Construct label with agent identification
    full_label = "$label: NodeId=$agent_id Name=$agent_name"
    
    return Aeron.add_counter(client, type_id, key_buffer, full_label)
end

"""
    Counters

Container for RtcFramework's standard performance counters.

Each counter is an `Aeron.Counter` allocated in the MediaDriver's shared memory,
visible via AeronStat for external monitoring.

# Fields
- `duty_cycles::Aeron.Counter`: Total duty cycles executed (work loop health)
- `work_done::Aeron.Counter`: Cumulative work units processed (throughput)
- `properties_published::Aeron.Counter`: Total property publications

# See Also
- `add_counter`: Helper function for creating custom counters
- Downstream packages can define their own Counters struct with domain-specific fields
"""
struct Counters
    duty_cycles::Aeron.Counter
    work_done::Aeron.Counter
    properties_published::Aeron.Counter
end

"""
    Counters(client::Aeron.Client, agent_id::Int64, agent_name::String) -> Counters

Allocate RtcFramework's standard performance counters in Aeron's shared memory.

Creates three counters with agent identification for external monitoring via AeronStat:
- Type ID 1001: TotalDutyCycles
- Type ID 1002: TotalWorkDone
- Type ID 1003: PropertiesPublished

# Arguments
- `client::Aeron.Client`: Aeron client instance
- `agent_id::Int64`: Unique agent identifier (NodeId)
- `agent_name::String`: Agent name for AeronStat display

# Returns
`Counters` struct with allocated Aeron.Counter fields.

# Example
```julia
counters = Counters(aeron_client, 42, "TestAgent")
Aeron.increment!(counters.duty_cycles)
work_count = counters.work_done[]
```
"""
function Counters(client::Aeron.Client, agent_id::Int64, agent_name::String)
    Counters(
        add_counter(client, agent_id, agent_name, Int32(1001), "TotalDutyCycles"),
        add_counter(client, agent_id, agent_name, Int32(1002), "TotalWorkDone"),
        add_counter(client, agent_id, agent_name, Int32(1003), "PropertiesPublished")
    )
end

"""
    Base.close(counters::Counters)

Close all Aeron counters in the Counters container.

This should be called during agent shutdown to properly release counter resources
in the MediaDriver's shared memory.
"""
function Base.close(counters::Counters)
    close(counters.duty_cycles)
    close(counters.work_done)
    close(counters.properties_published)
end

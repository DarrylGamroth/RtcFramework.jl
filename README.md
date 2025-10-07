# RtcFramework.jl

[![CI](https://github.com/DarrylGamroth/RtcFramework.jl/actions/workflows/ci.yml/badge.svg)](https://github.com/DarrylGamroth/RtcFramework.jl/actions/workflows/ci.yml)
[![codecov](https://codecov.io/gh/DarrylGamroth/RtcFramework.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/DarrylGamroth/RtcFramework.jl)

A high-performance, real-time control framework for Julia that provides zero-allocation operation, hierarchical state machines, and Aeron-based messaging for deterministic real-time systems.

## Quick Start

### 1. Define Your Properties

Use the `@base_properties` macro to include all standard RTC properties, then add your custom properties:

```julia
using RtcFramework
using StaticKV
using Clocks
using Hsm
using Logging

@kvstore Properties begin
    @base_properties
    
    # Add your custom properties
    SensorData::Vector{Float32} => zeros(Float32, 100)
    TargetPosition::Float64 => 0.0
    EnableFlag::Bool => false
end
```

### 2. Define Your Agent

Create your agent by wrapping `BaseRtcAgent`:

```julia
@hsmdef mutable struct MyAgent{T<:RtcFramework.BaseRtcAgent} <: RtcFramework.AbstractRtcAgent
    base::T
    # Add your service-specific fields here
    # custom_state::SomeType
end

# Implement required base accessor
RtcFramework.base(agent::MyAgent) = agent.base
```

### 3. Set Up Environment Variables

Configure your agent's communication streams:

```julia
# Required environment variables
ENV["BLOCK_NAME"] = "MyService"
ENV["BLOCK_ID"] = "1"
ENV["STATUS_URI"] = "aeron:ipc"
ENV["STATUS_STREAM_ID"] = "1001"
ENV["CONTROL_URI"] = "aeron:ipc"
ENV["CONTROL_STREAM_ID"] = "1002"
ENV["HEARTBEAT_PERIOD_NS"] = "1000000000"  # 1 second

# Optional: Configure data streams (auto-discovered by @base_properties)
ENV["PUB_DATA_URI_1"] = "aeron:ipc"
ENV["PUB_DATA_STREAM_1"] = "2001"
ENV["SUB_DATA_URI_1"] = "aeron:ipc"
ENV["SUB_DATA_STREAM_1"] = "3001"
```

### 4. Create and Run Your Agent

```julia
using RtcFramework
using Aeron
using Agent
using Clocks

# Create Aeron client
MediaDriver.launch_embedded() do driver
    Aeron.Context() do context
        Aeron.aeron_dir!(context, MediaDriver.aeron_dir(driver))
        Aeron.Client(context) do client
            # Create clock and properties
            clock = CachedEpochClock(EpochClock())
            properties = Properties(clock)
            
            # Create communication resources
            comms = CommunicationResources(client, properties)
            
            # Create base agent and wrap it
            base_agent = BaseRtcAgent(comms, properties, clock)
            agent = MyAgent(base_agent)
            
            # Start the agent
            runner = AgentRunner(BackoffIdleStrategy(), agent)
            Agent.start_on_thread(runner)

            try
                wait(runner)
            catch e
                if e isa InterruptException
                    @info "Shutting down..."
                else
                    @error "Exception caught:" exception = (e, catch_backtrace())
                end
            finally
                close(runner)
            end
        end
    end
end
```

## Core Concepts

All examples below assume you have an agent instance created as shown in the Quick Start.

### Property Publishing

Register properties with publication strategies:

```julia
# Publish on every update
register!(agent, :SensorData, 1, OnUpdate())

# Publish every 100ms
register!(agent, :TargetPosition, 1, Periodic(100_000_000))

# Publish at most once per 50ms (rate limiting)
register!(agent, :EnableFlag, 1, RateLimited(50_000_000))

# Publish at specific time
register!(agent, :Timestamp, 1, Scheduled(time_nanos(base(agent).clock) + 1_000_000_000))
```

### Publishing Status Events

```julia
# Publish a simple status event
publish_status_event(agent, :MyEvent, "Event data")

# Publish state changes
publish_state_change(agent, :NewState)

# Publish event responses
publish_event_response(agent, :CommandAck, true)
```

### Timer Scheduling

```julia
# Schedule a timer (relative delay)
schedule!(base(agent).timers, 1_000_000_000, :OneSecondTimer)  # 1 second from now

# Schedule at absolute time
schedule_at!(base(agent).timers, specific_timestamp_ns, :AbsoluteTimer)

# Cancel a timer
cancel!(base(agent).timers, :OneSecondTimer)
```

### Event Dispatch

Handle custom events by implementing `@on_event` handlers for your agent:

```julia
using Hsm

# Handle a custom event in a specific state (e.g., Playing)
@on_event function (agent::MyAgent, ::Playing, ::CustomCommand, data)
    @info "Received custom command" data
    publish_event_response(agent, :CommandAck, "Acknowledged")
    return Hsm.EventHandled
end
```

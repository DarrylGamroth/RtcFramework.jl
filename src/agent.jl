"""
    BaseRtcAgent{C,P,ID,ET}

Base structure for real-time control agent with hierarchical state machine and communication.

Manages event dispatch, property publishing, timer scheduling, and state
transitions. Generic parameters allow customization of core components.

# Type Parameters
- `C<:AbstractClock`: clock implementation for timing operations
- `P<:AbstractStaticKV`: property store implementation
- `ID<:SnowflakeIdGenerator`: unique ID generator for correlation
- `ET<:PolledTimer`: timer implementation for scheduled operations

# Fields
- `clock::C`: timing source for all operations
- `properties::P`: agent configuration and runtime properties
- `id_gen::ID`: correlation ID generator
- `source_correlation_id::Int64`: correlation ID of current event being processed
- `timers::ET`: timer scheduler for periodic operations
- `comms::CommunicationResources`: Aeron stream management
- `status_proxy::Union{Nothing,StatusProxy}`: status publishing interface
- `property_proxy::Union{Nothing,PropertyProxy}`: property publishing interface
- `control_adapter::Union{Nothing,ControlStreamAdapter}`: control message handler
- `input_adapters::Vector{InputStreamAdapter}`: input stream processors
- `property_registry::Vector{PublicationConfig}`: registered property configs
- `poller_registry::PollerRegistry`: poller management with deferred add/remove
- `counters::Counters`: Aeron-allocated performance counters for external observability
- `last_stats_time::Int64`: timestamp of last stats update (nanoseconds)
- `last_msg_count::Int64`: message count at last stats update (for rate calculation)
- `last_work_count::Int64`: work count at last stats update (for rate calculation)
"""
mutable struct BaseRtcAgent{C<:AbstractClock,P<:AbstractStaticKV,ID<:SnowflakeIdGenerator,ET<:PolledTimer}
    clock::C
    properties::P
    id_gen::ID
    source_correlation_id::Int64
    timers::ET
    comms::CommunicationResources
    status_proxy::Union{Nothing,StatusProxy}
    property_proxy::Union{Nothing,PropertyProxy}
    control_adapter::Union{Nothing,ControlStreamAdapter}
    input_adapters::Vector{InputStreamAdapter}
    property_registry::Vector{PublicationConfig}
    poller_registry::PollerRegistry
    counters::Counters
    last_stats_time::Int64
    last_msg_count::Int64
    last_work_count::Int64
end

function BaseRtcAgent(comms::CommunicationResources, properties::AbstractStaticKV, clock::C=CachedEpochClock(EpochClock())) where {C<:Clocks.AbstractClock}
    fetch!(clock)

    id_gen = SnowflakeIdGenerator(properties[:NodeId], clock)
    timers = PolledTimer(clock)

    # Allocate Aeron counters for observability with agent identification
    agent_id = properties[:NodeId]
    agent_name = properties[:Name]
    counters = Counters(comms.client, agent_id, agent_name)

    # Create the agent with proxy fields initialized to nothing
    BaseRtcAgent(
        clock,
        properties,
        id_gen,
        0,
        timers,
        comms,
        nothing,
        nothing,
        nothing,
        InputStreamAdapter[],
        PublicationConfig[],
        PollerRegistry(),
        counters,
        0,
        0,
        0
    )
end

# =============================================================================
# Agent.jl Protocol Implementation
# =============================================================================

"""
    Agent.name(agent::AbstractRtcAgent)

Get the name of this agent from its property store.
"""
Agent.name(agent::AbstractRtcAgent) = base(agent).properties[:Name]

"""
    Agent.on_start(agent::AbstractRtcAgent)

Initialize the agent by setting up communications and starting the state machine.

Creates control and input stream adapters, and status/property proxies.
"""
function Agent.on_start(agent::AbstractRtcAgent)
    @info "Starting agent $(Agent.name(agent))"

    b = base(agent)
    try
        # Create control stream adapter
        b.control_adapter = ControlStreamAdapter(
            b.comms.control_stream,
            agent
        )

        # Create input stream adapters
        empty!(b.input_adapters)
        for input_stream in b.comms.input_streams
            push!(b.input_adapters, InputStreamAdapter(input_stream, agent))
        end

        # Create proxy instances
        b.status_proxy = StatusProxy(b.comms.status_stream)
        b.property_proxy = PropertyProxy(b.comms.output_streams)

    catch e
        throw(AgentCommunicationError("Failed to initialize communication resources: $(e)"))
    end

    # Register pollers

    # Input stream polling
    register_poller!(input_poller, agent, :input_streams, PRIORITY_INPUT)

    # Property publishing
    register_poller!(property_poller, agent, :properties, PRIORITY_PROPERTY)

    # Timer events
    register_poller!(timer_poller, agent, :timers, PRIORITY_TIMER)

    # Control stream polling (lowest priority of built-ins)
    register_poller!(control_poller, agent, :control_stream, PRIORITY_CONTROL)

    nothing
end

"""
    Agent.on_close(agent::AbstractRtcAgent)

Shutdown the agent by tearing down communications and stopping timers.

Cancels all timers, closes communication resources, and clears adapters/proxies.
"""
function Agent.on_close(agent::AbstractRtcAgent)
    @info "Stopping agent $(Agent.name(agent))"

    b = base(agent)

    # Cancel all timers
    cancel!(b.timers)

    # Clear all pollers
    clear_pollers!(agent)

    # Close counters
    close(b.counters)

    # Close communication resources
    close(b.comms)

    # Clear adapters and proxies
    b.control_adapter = nothing
    b.status_proxy = nothing
    b.property_proxy = nothing
    empty!(b.input_adapters)
end

"""
    Agent.on_error(agent::AbstractRtcAgent, error)

Handle agent errors by logging them.
"""
function Agent.on_error(agent::AbstractRtcAgent, error)
    @error "Error in agent $(Agent.name(agent)):" exception = (error, catch_backtrace())
end

"""
    Agent.do_work(agent::AbstractRtcAgent)

Perform one unit of work by polling all registered pollers in priority order.

Updates the clock and executes all pollers (built-in and custom) sorted by priority.
Applies any pending add/remove operations after the poll cycle completes.
Returns the total number of work items processed.
"""
function Agent.do_work(agent::AbstractRtcAgent)
    b = base(agent)
    fetch!(b.clock)

    work_count = poll_pollers!(b.poller_registry, agent)

    counters = b.counters
    increment_counter!(counters, TOTAL_DUTY_CYCLES)
    increment_counter!(counters, TOTAL_WORK_DONE, work_count)

    return work_count
end

# =============================================================================
# Polling Functions
# =============================================================================

"""
    input_poller(agent::AbstractRtcAgent) -> Int

Poll all input streams for incoming data messages using input stream adapters.

Returns the number of fragments processed.
"""
function input_poller(agent::AbstractRtcAgent)
    b = base(agent)
    poll(b.input_adapters, DEFAULT_INPUT_FRAGMENT_COUNT_LIMIT)
end

"""
    control_poller(agent::AbstractRtcAgent) -> Int

Poll the control stream for incoming control messages using the control stream adapter.

Returns the number of fragments processed.
"""
function control_poller(agent::AbstractRtcAgent)
    b = base(agent)
    adapter = b.control_adapter::ControlStreamAdapter
    poll(adapter, DEFAULT_CONTROL_FRAGMENT_COUNT_LIMIT)
end

"""
    timer_poller(agent::AbstractRtcAgent) -> Int

Poll the timer system for expired timers and dispatch their events.

Returns the number of timers that fired.
"""
function timer_poller(agent::AbstractRtcAgent)
    Timers.poll(base(agent).timers, agent) do event, now, agent
        b = base(agent)
        b.source_correlation_id = next_id(b.id_gen)
        dispatch!(agent, event, now)
    end
end

"""
    property_poller(agent::AbstractRtcAgent) -> Int

Poll all registered properties and dispatch publish events when strategies indicate.

Checks publication strategies for each registered property. When a property should
be published, dispatches a :PublishProperty event with the config, updates timing
state, and counts the dispatch. Returns the number of properties that should publish.
"""
function property_poller(agent::AbstractRtcAgent)
    b = base(agent)
    registry = b.property_registry

    if isempty(registry)
        return 0
    end

    now = time_nanos(b.clock)
    count = 0

    @inbounds for i in 1:length(registry)
        config = registry[i]
        property_timestamp_ns = last_update(b.properties, config.field)

        if should_publish(config.strategy, config.last_published_ns,
                         config.next_scheduled_ns, property_timestamp_ns, now)
            b.source_correlation_id = next_id(b.id_gen)
            dispatch!(agent, :PublishProperty, config)
            config.last_published_ns = now
            config.next_scheduled_ns = next_time(config.strategy, now)
            count += 1
        end
    end

    if count > 0
        increment_counter!(b.counters, PROPERTIES_PUBLISHED, count)
    end

    return count
end

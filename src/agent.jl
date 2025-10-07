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
- `pollers::Vector{PollerConfig}`: registered pollers in priority order
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
    pollers::Vector{PollerConfig}
end

function BaseRtcAgent(comms::CommunicationResources, properties::AbstractStaticKV, clock::C=CachedEpochClock(EpochClock())) where {C<:Clocks.AbstractClock}
    fetch!(clock)

    id_gen = SnowflakeIdGenerator(properties[:NodeId], clock)
    timers = PolledTimer(clock)

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
        PollerConfig[]
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

    # Register built-in pollers
    register_builtin_pollers!(agent)

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
Returns the total number of work items processed.
"""
function Agent.do_work(agent::AbstractRtcAgent)
    b = base(agent)
    fetch!(b.clock)

    work_count = 0
    pollers = b.pollers

    # Type-stable iteration over pollers
    @inbounds for i in 1:length(pollers)
        work_count += pollers[i].poll_fn(agent)
    end

    return work_count
end

# =============================================================================
# Built-in Poller Registration
# =============================================================================

"""
    register_builtin_pollers!(agent::AbstractRtcAgent)

Register the framework's built-in pollers in priority order.

This is called automatically during `on_start`. Users can override priorities
by unregistering and re-registering with different priorities if needed.
"""
function register_builtin_pollers!(agent::AbstractRtcAgent)
    # Input stream polling (highest priority)
    register_poller!(input_poller, agent, PRIORITY_INPUT; name=:input_streams)

    # Property publishing
    register_poller!(property_poller, agent, PRIORITY_PROPERTY; name=:properties)

    # Timer events
    register_poller!(timer_poller, agent, PRIORITY_TIMER; name=:timers)

    # Control stream polling (lowest priority of built-ins)
    register_poller!(control_poller, agent, PRIORITY_CONTROL; name=:control_stream)
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

Poll all registered properties for updates.

Only polls when in :Playing state. Returns the number of properties published.
"""
function property_poller(agent::AbstractRtcAgent)
    b = base(agent)
    if !should_poll_properties(agent) || isempty(b.property_registry)
        return 0
    end

    published_count = 0
    registry = b.property_registry

    @inbounds for i in 1:length(registry)
        published_count += publish_property_update(agent, registry[i])
    end

    return published_count
end

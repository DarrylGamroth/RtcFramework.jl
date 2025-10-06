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
        PublicationConfig[]
    )
end

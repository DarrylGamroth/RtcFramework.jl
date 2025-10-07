"""
Property registration and management for agent publication system.

Provides functions for registering, unregistering, and querying properties
in the agent's publication registry for scheduled property updates.
"""

"""
    register!(agent::AbstractRtcAgent, field::Symbol, stream_index::Int, strategy::PublishStrategy)

Register a property for publication using a publication stream by index.

The stream_index corresponds to the publication stream (1-based).
A property can be registered multiple times with different streams and strategies.

# Arguments
- `agent::AbstractRtcAgent`: the agent whose property registry to update
- `field::Symbol`: the property field name to register
- `stream_index::Int`: the output stream index (1-based)
- `strategy::PublishStrategy`: publication strategy (OnUpdate, Periodic, etc.)

# Throws
- `StreamNotFoundError`: if stream_index is out of bounds
"""
function register!(agent::AbstractRtcAgent,
    field::Symbol,
    stream_index::Int,
    strategy::PublishStrategy)

    b = base(agent)
    # Validate stream index and get publication
    output_streams = b.comms.output_streams
    if stream_index < 1 || stream_index > length(output_streams)
        throw(StreamNotFoundError("PubData$stream_index", stream_index))
    end

    # Create and add the configuration to the registry
    config = PublicationConfig(
        -1,
        next_time(strategy, 0),
        field,
        stream_index,
        strategy,
        output_streams[stream_index]
    )
    push!(b.property_registry, config)

    @info "Registered property: $field on stream $stream_index with strategy $strategy"
end

"""
    unregister!(agent::AbstractRtcAgent, field::Symbol, stream_index::Int) -> Int

Remove a specific property-stream registration from the publication registry.

Returns the number of registrations removed (0 or 1).
"""
function unregister!(agent::AbstractRtcAgent, field::Symbol, stream_index::Int)
    if !isregistered(agent, field, stream_index)
        return 0
    end

    b = base(agent)
    indices = findall(config -> config.field == field && config.stream_index == stream_index, b.property_registry)
    deleteat!(b.property_registry, indices)

    @info "Unregistered property: $field on stream $stream_index"

    return length(indices)
end

"""
    unregister!(agent::AbstractRtcAgent, field::Symbol) -> Int

Remove all registrations for a property field from the publication registry.

Returns the number of registrations removed.
"""
function unregister!(agent::AbstractRtcAgent, field::Symbol)
    if !isregistered(agent, field)
        return 0
    end

    b = base(agent)
    indices = findall(config -> config.field == field, b.property_registry)
    deleteat!(b.property_registry, indices)

    @info "Unregistered property: $field"

    return length(indices)
end

"""
    isregistered(agent::AbstractRtcAgent, field::Symbol) -> Bool
    isregistered(agent::AbstractRtcAgent, field::Symbol, stream_index::Int) -> Bool

Check if a property is registered for publication.

With only field specified, returns true if the field is registered on any stream.
With both field and stream_index specified, returns true if the field is registered on that specific stream.
"""
isregistered(agent::AbstractRtcAgent, field::Symbol) = any(config -> config.field == field, base(agent).property_registry)
isregistered(agent::AbstractRtcAgent, field::Symbol, stream_index::Int) = any(config -> config.field == field && config.stream_index == stream_index, base(agent).property_registry)

"""
    Base.empty!(agent::AbstractRtcAgent) -> Int

Clear all registered property publications.

Returns the number of registrations removed.
"""
function Base.empty!(agent::AbstractRtcAgent)
    b = base(agent)
    count = length(b.property_registry)
    empty!(b.property_registry)
    return count
end

"""
    should_poll_properties(agent::AbstractRtcAgent) -> Bool

Determine whether property polling should be active based on agent state.

Property polling is only active when the agent is in the :Playing state.
"""
function should_poll_properties(agent::AbstractRtcAgent)
    return Hsm.current(agent) === :Playing
end

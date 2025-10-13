"""
Publishing convenience functions for agent message output.

Provides high-level functions for publishing status events, state changes,
and property values through agent proxies with automatic timestamp and
correlation ID management.
"""

"""
    publish_status_event(agent::AbstractRtcAgent, event::Symbol, data)

Publish a status event using the agent's status proxy.

Convenience method that automatically handles timestamp generation and agent name.
Throws `AgentStateError` if the status proxy is not initialized.
"""
function publish_status_event(agent::AbstractRtcAgent, event::Symbol, data)
    b = base(agent)
    timestamp = time_nanos(b.clock)
    proxy = b.status_proxy::StatusProxy

    return publish_status_event(
        proxy, event, data, b.properties[:Name], b.source_correlation_id, timestamp
    )
end

"""
    publish_state_change(agent::AbstractRtcAgent, new_state::Symbol)

Publish a state change event using the agent's status proxy.

Convenience method for reporting agent state transitions.
"""
function publish_state_change(agent::AbstractRtcAgent, new_state::Symbol)
    b = base(agent)
    timestamp = time_nanos(b.clock)
    proxy = b.status_proxy::StatusProxy

    return publish_state_change(
        proxy, new_state, b.properties[:Name], b.source_correlation_id, timestamp
    )
end

"""
    publish_event_response(agent::AbstractRtcAgent, event::Symbol, value)

Publish an event response using the agent's status proxy.

Convenience method for sending responses to control events.
"""
function publish_event_response(agent::AbstractRtcAgent, event::Symbol, value)
    b = base(agent)
    timestamp = time_nanos(b.clock)
    proxy = b.status_proxy::StatusProxy

    return publish_event_response(
        proxy, event, value, b.properties[:Name], b.source_correlation_id, timestamp
    )
end

"""
    publish_property(agent::AbstractRtcAgent, stream_index::Int, field::Symbol, value)

Publish a property value to a specific output stream using the agent's property proxy.

Convenience method that validates the property exists and handles timestamp generation.
"""
function publish_property(agent::AbstractRtcAgent, stream_index::Int, field::Symbol, value)
    b = base(agent)
    # Validate field exists in properties
    if !haskey(b.properties, field)
        throw(KeyError("Property $field not found in agent"))
    end

    timestamp = time_nanos(b.clock)
    proxy = b.property_proxy::PropertyProxy

    return publish_property(proxy, stream_index, field, value,
        b.properties[:Name], b.source_correlation_id, timestamp)
end

"""
    publish_property(agent::AbstractRtcAgent, config::PublicationConfig)

Publish a property value using publication configuration.

Convenience method that extracts stream index, field, and value from the config
and agent properties, then publishes to the appropriate stream.
"""
function publish_property(agent::AbstractRtcAgent, config::PublicationConfig)
    b = base(agent)
    timestamp = time_nanos(b.clock)
    proxy = b.property_proxy::PropertyProxy

    return publish_property(proxy, config.stream_index, config.field, 
        b.properties[config.field], b.properties[:Name], b.source_correlation_id, timestamp)
end

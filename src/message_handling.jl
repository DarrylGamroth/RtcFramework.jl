"""
Message decoding and property handling utilities.

Provides functions for decoding SBE messages into Julia types, setting property
values with appropriate copying semantics, and handling property read/write events.
"""

"""
    decode_property_value(message, ::Type{T}) where {T<:AbstractArray}

Decode an array property value from a tensor message.

Extracts tensor data from SBE message format and reconstructs the array.
"""
function decode_property_value(message, ::Type{A}) where {T,N,A<:AbstractArray{T,N}}
    tensor_message = SpidersMessageCodecs.value(message, SpidersMessageCodecs.TensorMessage)

    prop_sbe_type = convert(SpidersMessageCodecs.Format.SbeEnum, T)
    message_sbe_type = SpidersMessageCodecs.format(tensor_message)

    if message_sbe_type != prop_sbe_type
        throw(ErrorException("Property type mismatch for $event: expected $prop_sbe_type, got $message_sbe_type"))
    end

    SpidersMessageCodecs.decode(tensor_message, A)
end

"""
    decode_property_value(message, ::Type{T}) where {T}

Decode a scalar property value from an event message.

Generic fallback for non-array types including strings, numbers, and symbols.
"""
function decode_property_value(message, ::Type{T}) where {T}
    prop_sbe_type = convert(SpidersMessageCodecs.Format.SbeEnum, T)
    message_sbe_type = SpidersMessageCodecs.format(message)

    if message_sbe_type != prop_sbe_type
        throw(ErrorException("Property type mismatch for $event: expected $prop_sbe_type, got $message_sbe_type"))
    end
    SpidersMessageCodecs.value(message, T)
end

"""
    set_property_value!(properties, event, value, ::Type{T}) where {T<:AbstractArray}

Set an array property value with copy semantics.

Collects the array value to avoid aliasing issues with message buffers.
"""
function set_property_value!(properties::AbstractStaticKV, event::Symbol, value, ::Type{T}) where {T<:AbstractArray}
    # If the property is an array, we need to copy it
    setindex!(properties, copy(value), event)
end

"""
    set_property_value!(properties, event, value, ::Type{T}) where {T<:AbstractString}

Set a string property value with copy semantics.

Collects the string value to avoid aliasing with message buffer data.
"""
function set_property_value!(properties::AbstractStaticKV, event::Symbol, value, ::Type{T}) where {T<:AbstractString}
    setindex!(properties, String(value), event)
end

"""
    set_property_value!(properties, event, value, ::Type{T}) where {T}

Set a scalar property value directly without copying.

Generic fallback for bits types that can be stored directly.
"""
# Generic fallback for all other types (bits types, etc.)
function set_property_value!(properties::AbstractStaticKV, event::Symbol, value, ::Type{T}) where {T}
    setindex!(properties, value, event)
end

"""
    on_property_write(sm, event, message)

Handle a property write request by decoding and storing the new value.

Decodes the property value from the message, updates the property store,
and publishes a status event confirming the change.
"""
function on_property_write(sm::AbstractRtcAgent, event::Symbol, message)
    b = base(sm)
    prop_type = valtype(b.properties, event)
    value = decode_property_value(message, prop_type)

    set_property_value!(b.properties, event, value, prop_type)
    publish_event_response(sm, event, value)
end

"""
    on_property_read(sm, event, _)

Handle a property read request by publishing the current value.

Checks if the property exists and publishes its current value as a status event.
"""
function on_property_read(sm::AbstractRtcAgent, event::Symbol, _)
    b = base(sm)
    if isset(b.properties, event)
        value = b.properties[event]
        publish_event_response(sm, event, value)
    else
        publish_event_response(sm, event, nothing)
    end
end

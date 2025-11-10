"""
    PropertyProxy

Proxy for publishing property values to multiple output streams.

Contains minimal components for Aeron message publishing with stream selection.
The `publications` vector enables routing to different streams based on index.

# Fields
- `position_ptr::Base.RefValue{Int64}`: current buffer position for SBE encoding
- `publications::Vector{Aeron.ExclusivePublication}`: multiple output streams
- `buffer::Vector{UInt8}`: reusable buffer for message construction
"""
struct PropertyProxy
    position_ptr::Base.RefValue{Int64}
    publications::Vector{Aeron.ExclusivePublication}
    buffer::Vector{UInt8}
    function PropertyProxy(publications::Vector{Aeron.ExclusivePublication})
        new(Ref{Int64}(0), publications, zeros(UInt8, 256))
    end
end

"""
    publish_property(proxy, stream_index, field, value, tag, correlation_id, timestamp_ns)

Publish a property value to the specified output stream with SBE encoding.

Routes to the output stream by index and handles buffer claiming and message encoding.
Returns `nothing` on success or when no subscribers are present.

# Arguments
- `stream_index::Int`: 1-based index into the publications vector
- `field::Symbol`: property field name
- `value`: property value (string, char, number, symbol, or tuple)
- `tag::AbstractString`: message tag for identification
- `correlation_id::Int64`: unique correlation identifier
- `timestamp_ns::Int64`: message timestamp in nanoseconds
"""
function publish_property(
    proxy::PropertyProxy,
    stream_index::Int,
    field::Symbol,
    value::T,
    tag::AbstractString,
    correlation_id::Int64,
    timestamp_ns::Int64) where {T<:Union{AbstractString,Char,Real,Nothing,Symbol,Tuple}}

    # Calculate buffer length needed
    len = sbe_encoded_length(MessageHeader) +
          sbe_block_length(EventMessage) +
          SpidersMessageCodecs.value_header_length(EventMessage) +
          sizeof(value)

    # Try to claim the buffer
    claim = try_claim(proxy.publications[stream_index], len)

    # If claiming the buffer fails, return early
    isnothing(claim) && return

    # Create the message encoder
    encoder = EventMessageEncoder(Aeron.buffer(claim); position_ptr=proxy.position_ptr)
    header = SpidersMessageCodecs.header(encoder)

    # Fill in the message
    SpidersMessageCodecs.timestampNs!(header, timestamp_ns)
    SpidersMessageCodecs.correlationId!(header, correlation_id)
    SpidersMessageCodecs.tag!(header, tag)
    SpidersMessageCodecs.format!(encoder, convert(SpidersMessageCodecs.Format.SbeEnum, T))
    SpidersMessageCodecs.key!(encoder, field)
    SpidersMessageCodecs.value!(encoder, value)

    # Commit the message
    Aeron.commit(claim)

    nothing
end

"""
    publish_property(proxy, stream_index, field, value::AbstractArray, tag, correlation_id, timestamp_ns)

Publish an array property value with SBE tensor encoding.

Routes to the specified output stream by index with efficient tensor format.
"""
function publish_property(
    proxy::PropertyProxy,
    stream_index::Int,
    field::Symbol,
    value::T,
    tag::AbstractString,
    correlation_id::Int64,
    timestamp_ns::Int64) where {T<:AbstractArray}

    # Calculate array data length
    len = sizeof(eltype(value)) * length(value)

    # Create tensor message
    encoder = TensorMessageEncoder(proxy.buffer; position_ptr=proxy.position_ptr)
    header = SpidersMessageCodecs.header(encoder)
    SpidersMessageCodecs.timestampNs!(header, timestamp_ns)
    SpidersMessageCodecs.correlationId!(header, correlation_id)
    SpidersMessageCodecs.tag!(header, field)
    SpidersMessageCodecs.format!(encoder, convert(SpidersMessageCodecs.Format.SbeEnum, eltype(value)))
    SpidersMessageCodecs.majorOrder!(encoder, SpidersMessageCodecs.MajorOrder.COLUMN)
    SpidersMessageCodecs.dims!(encoder, Int32.(size(value)))
    SpidersMessageCodecs.origin!(encoder, nothing)
    @inbounds SpidersMessageCodecs.values_length!(encoder, len)
    SpidersMessageCodecs.sbe_position!(encoder, sbe_position(encoder) + SpidersMessageCodecs.values_header_length(encoder))
    tensor_message = convert(AbstractArray{UInt8}, encoder)

    # Offer the combined message
    offer(proxy.publications[stream_index],
        (
            tensor_message,
            vec(reinterpret(UInt8, value))
        )
    )

    nothing
end

function publish_property(
    proxy::PropertyProxy,
    stream_index::Int,
    field::Symbol,
    value,
    tag::AbstractString,
    correlation_id::Int64,
    timestamp_ns::Int64)

    # Fallback for unsupported types - treat as nothing
    publish_property(proxy, stream_index, field, nothing, tag, correlation_id, timestamp_ns)
end

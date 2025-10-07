include("strategies.jl")
include("publication_helpers.jl")

"""
    PublicationConfig

Configuration for property publication with timing and strategy management.

Tracks publication state and controls when property values are published based
on the configured strategy. Fields are ordered by access frequency.

# Fields
- `last_published_ns::Int64`: timestamp of last publication in nanoseconds
- `next_scheduled_ns::Int64`: next scheduled publication time in nanoseconds
- `field::Symbol`: property field name to publish
- `stream_index::Int`: target output stream index (1-based)
- `strategy::PublishStrategy`: publication timing strategy
- `stream::Aeron.ExclusivePublication`: direct stream reference for efficiency
"""
mutable struct PublicationConfig
    last_published_ns::Int64
    next_scheduled_ns::Int64
    field::Symbol
    stream_index::Int
    strategy::PublishStrategy
    stream::Aeron.ExclusivePublication
end

include("status_proxy.jl")
include("property_proxy.jl")

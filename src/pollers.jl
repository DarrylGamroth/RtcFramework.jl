"""
Type-stable function wrapper for poller functions.
Signature: (agent::AbstractRtcAgent) -> Int (work count)
"""
const PollerFunction = FunctionWrapper{Int,Tuple{AbstractRtcAgent}}

"""
    PollerConfig

Configuration for a registered poller including its function, priority, and name.

# Fields
- `poll_fn::PollerFunction`: Type-stable polling function
- `priority::Int`: Priority level (lower = higher priority)
- `name::Symbol`: Identifier for debugging and management
"""
struct PollerConfig
    poll_fn::PollerFunction
    priority::Int
    name::Symbol
end

# Built-in poller priorities (internal constants, not exported)
const PRIORITY_INPUT = 10              # Input stream polling
const PRIORITY_PROPERTY = 50           # Property publishing
const PRIORITY_TIMER = 75              # Timer events
const PRIORITY_CONTROL = 200           # Control messages

"""
    register_poller!(poll_fn, agent::AbstractRtcAgent, priority::Int; name::Symbol)

Register a poller function with the agent at the specified priority level.
Lower priority values are polled first (0 = highest priority).

Pollers with the same priority execute in registration order (FIFO).

# Arguments
- `poll_fn`: Function with signature `(agent::AbstractRtcAgent) -> Int`
- `agent`: The agent to register with
- `priority`: Priority level as Int (built-in pollers use 10, 50, 75, 200)
- `name`: Required identifier for the poller

# Returns
The index where the poller was inserted.

# Examples
```julia
# Register a custom poller with high priority (between input=10 and property=50)
register_poller!(my_custom_poll_fn, agent, 25, name=:custom_sensor)

# Register with inline function at normal priority
register_poller!(agent, 100, name=:my_poller) do agent
    # Poll logic here
    return work_count
end

# Register multiple pollers at same priority (execute in registration order)
register_poller!(poll_a, agent, 100, name=:poller_a)  # Runs first
register_poller!(poll_b, agent, 100, name=:poller_b)  # Runs second
```
"""
function register_poller!(poll_fn, agent::AbstractRtcAgent, priority::Int; name::Symbol)
    b = base(agent)

    # Wrap function for type stability
    wrapped_fn = PollerFunction(poll_fn)
    config = PollerConfig(wrapped_fn, priority, name)

    # Find insertion point to maintain sorted order by priority
    # Use searchsortedlast to ensure FIFO ordering for same-priority pollers
    insert_idx = searchsortedlast(b.pollers, config; by=c -> c.priority) + 1

    insert!(b.pollers, insert_idx, config)

    return insert_idx
end

"""
    unregister_poller!(agent::AbstractRtcAgent, name::Symbol) -> Bool

Unregister a poller by name.

# Returns
`true` if a poller was found and removed, `false` otherwise.

# Examples
```julia
unregister_poller!(agent, :my_custom_poller)
```
"""
function unregister_poller!(agent::AbstractRtcAgent, name::Symbol)
    b = base(agent)

    idx = findfirst(c -> c.name == name, b.pollers)

    if idx !== nothing
        deleteat!(b.pollers, idx)
        return true
    end

    return false
end

"""
    clear_pollers!(agent::AbstractRtcAgent) -> Int

Remove all pollers from the agent (including built-in pollers).

**Warning**: This removes built-in pollers too. Use with caution.

# Returns
The number of pollers that were removed.
"""
function clear_pollers!(agent::AbstractRtcAgent)
    b = base(agent)
    count = length(b.pollers)
    empty!(b.pollers)
    return count
end

"""
    list_pollers(agent::AbstractRtcAgent) -> Vector{NamedTuple}

Get information about all registered pollers.

# Returns
Vector of `(name=Symbol, priority=Int, position=Int)` tuples.
"""
function list_pollers(agent::AbstractRtcAgent)
    b = base(agent)
    return [(; name=config.name, priority=config.priority, position=i)
            for (i, config) in enumerate(b.pollers)]
end

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

"""
    PollerLoop

Internal structure for managing pollers with deferred add/remove operations.
Pollers can safely request add/remove during iteration without breaking the loop.

# Fields
- `pollers::Vector{PollerConfig}`: Current active pollers (sorted by priority)
- `add::Vector{PollerConfig}`: Buffer for pollers to add after iteration
- `remove::Vector{Symbol}`: Names queued for removal after iteration
"""
struct PollerLoop
    pollers::Vector{PollerConfig}
    add::Vector{PollerConfig}
    remove::Vector{Symbol}
end

PollerLoop() = PollerLoop(PollerConfig[], PollerConfig[], Symbol[])

# =============================================================================
# Collections Interface for PollerLoop
# =============================================================================

"""
Implement the collections interface for PollerLoop.
Allows iteration, length queries, and indexed access to active pollers.
"""

# Iteration interface - iterate over active pollers only
Base.iterate(loop::PollerLoop) = iterate(loop.pollers)
Base.iterate(loop::PollerLoop, state) = iterate(loop.pollers, state)

# Length and size
Base.length(loop::PollerLoop) = length(loop.pollers)
Base.size(loop::PollerLoop) = (length(loop.pollers),)

# Element type
Base.eltype(::Type{PollerLoop}) = PollerConfig

# Indexed access - read-only access to active pollers
Base.getindex(loop::PollerLoop, i::Int) = loop.pollers[i]

# Keys for dictionary-like access (1-based indexing)
Base.keys(loop::PollerLoop) = keys(loop.pollers)
Base.firstindex(loop::PollerLoop) = 1
Base.lastindex(loop::PollerLoop) = length(loop.pollers)

# Check if empty
Base.isempty(loop::PollerLoop) = isempty(loop.pollers)

# Empty the collection
function Base.empty!(loop::PollerLoop)
    empty!(loop.add)
    empty!(loop.remove)
    empty!(loop.pollers)
    return loop
end

# Membership test - check if poller name exists
Base.in(name::Symbol, loop::PollerLoop) = any(c -> c.name == name, loop.pollers)

# Built-in poller priorities (internal constants, not exported)
const PRIORITY_INPUT = 10              # Input stream polling
const PRIORITY_PROPERTY = 50           # Property publishing
const PRIORITY_TIMER = 75              # Timer events
const PRIORITY_CONTROL = 200           # Control messages

# =============================================================================
# Internal PollerLoop Operations
# =============================================================================

"""
    pending_removal(loop::PollerLoop, name::Symbol) -> Bool

Check whether a poller name is already queued for removal.
"""
pending_removal(loop::PollerLoop, name::Symbol) = any(==(name), loop.remove)

"""
    ensure_unique_name!(loop::PollerLoop, name::Symbol)

Throw if a poller with the given name is already active or queued for addition.
Names slated for removal are ignored so callers can unregister then register
within the same cycle.
"""
function ensure_unique_name!(loop::PollerLoop, name::Symbol)
    for config in loop.add
        if config.name == name
            throw(ArgumentError("Poller name $(name) already registered"))
        end
    end

    if pending_removal(loop, name)
        return nothing
    end

    for config in loop.pollers
        if config.name == name
            throw(ArgumentError("Poller name $(name) already registered"))
        end
    end

    return nothing
end

"""
    request_add!(loop::PollerLoop, config::PollerConfig)

Request to add a poller after the current poll iteration completes.
Safe to call from within a poller function.
"""
function request_add!(loop::PollerLoop, config::PollerConfig)
    ensure_unique_name!(loop, config.name)
    push!(loop.add, config)
    return nothing
end

"""
    request_remove!(loop::PollerLoop, name::Symbol)

Request to remove a poller after the current poll iteration completes.
Safe to call from within a poller function.
"""
function request_remove!(loop::PollerLoop, name::Symbol)
    # Cancel pending additions with the same name before queueing removal.
    for i in length(loop.add):-1:1
        if loop.add[i].name == name
            deleteat!(loop.add, i)
            return nothing
        end
    end

    if pending_removal(loop, name)
        return nothing
    end

    push!(loop.remove, name)
    return nothing
end

"""
    apply_poller_changes!(loop::PollerLoop)

Apply pending add/remove operations to the poller list.
Called internally after each poll iteration.

# Algorithm
1. Remove pollers with names queued in remove (order-preserving filter)
2. Insert queued pollers into the sorted list using binary search
3. Clear buffers
"""
function apply_poller_changes!(loop::PollerLoop)
    # 1) Remove requested pollers (order-preserving, allocation-free)
    if !isempty(loop.remove)
        filter!(loop.pollers) do config
            # Keep the poller if its name is NOT in the remove list
            !any(==(config.name), loop.remove)
        end
        empty!(loop.remove)
    end

    # 2) Add new pollers
    if !isempty(loop.add)
        for config in loop.add
            # Preserve FIFO order for identical priorities by inserting after
            # the last poller with the same priority.
            priorities = [c.priority for c in loop.pollers]
            insert_at = searchsortedlast(priorities, config.priority)
            insert!(loop.pollers, insert_at + 1, config)
        end
        empty!(loop.add)
    end

    return nothing
end

"""
    poll_pollers!(loop::PollerLoop, agent::AbstractRtcAgent) -> Int

Execute a single poll cycle across the current poller set and apply any queued
add/remove operations afterwards.
"""
@inline function poll_pollers!(loop::PollerLoop, agent::AbstractRtcAgent)
    pollers = loop.pollers
    work_count = 0

    # Type-stable iteration over current snapshot of pollers. Structural changes
    # are deferred via the add/remove buffers.
    @inbounds for i in 1:length(pollers)
        work_count += pollers[i].poll_fn(agent)
    end

    apply_poller_changes!(loop)
    return work_count
end

# =============================================================================
# Public API
# =============================================================================

"""
    register_poller!(poll_fn, agent::AbstractRtcAgent, priority::Int; name::Symbol)

Register a poller function with the agent at the specified priority level.
Lower priority values are polled first (0 = highest priority).

Pollers with the same priority execute in registration order (FIFO) and each
poller name must be unique. Attempting to register a duplicate name throws an
`ArgumentError`.

**Note**: Registration is deferred and applied after the current poll cycle completes.
This makes it safe to register pollers from within other pollers.

# Arguments
- `poll_fn`: Function with signature `(agent::AbstractRtcAgent) -> Int`
- `agent`: The agent to register with
- `priority`: Priority level as Int (built-in pollers use 10, 50, 75, 200)
- `name`: Required identifier for the poller

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
    loop = b.poller_loop

    # Wrap function for type stability
    wrapped_fn = PollerFunction(poll_fn)
    config = PollerConfig(wrapped_fn, priority, name)

    # Defer the add operation
    request_add!(loop, config)

    return nothing
end

"""
    unregister_poller!(agent::AbstractRtcAgent, name::Symbol) -> Bool

Unregister a poller by name.

**Note**: Removal is deferred and applied after the current poll cycle completes.
This makes it safe to unregister pollers from within other pollers.

# Returns
`true` if a poller with the given name was found (will be removed after current cycle),
`false` otherwise.

# Examples
```julia
unregister_poller!(agent, :my_custom_poller)
```
"""
function unregister_poller!(agent::AbstractRtcAgent, name::Symbol)
    b = base(agent)
    loop = b.poller_loop

    # Cancel any pending addition first
    for i in length(loop.add):-1:1
        if loop.add[i].name == name
            deleteat!(loop.add, i)
            return true
        end
    end

    idx = findfirst(c -> c.name == name, loop.pollers)

    if idx !== nothing
        request_remove!(loop, name)
        return true
    end

    return false
end

"""
    clear_pollers!(agent::AbstractRtcAgent) -> Int

Remove all pollers from the agent immediately (including built-in pollers).

**Warning**: This removes built-in pollers too. Use with caution.
**Note**: Unlike register/unregister, this operation is immediate.

# Returns
The number of pollers that were removed.
"""
function clear_pollers!(agent::AbstractRtcAgent)
    b = base(agent)
    loop = b.poller_loop

    count = length(loop)
    empty!(loop)

    return count
end

"""
    pollers(agent::AbstractRtcAgent) -> PollerLoop

Get the poller collection for the agent. The returned PollerLoop implements the
Julia collections interface, allowing iteration, length queries, membership tests, etc.

# Examples
```julia
# Iterate over pollers
for config in pollers(agent)
    println(config.name, " priority=", config.priority)
end

# Query operations
length(pollers(agent))
isempty(pollers(agent))
:my_poller in pollers(agent)

# Indexed access
first_poller = pollers(agent)[1]
```
"""
pollers(agent::AbstractRtcAgent) = base(agent).poller_loop

"""
    Base.in(name::Symbol, agent::AbstractRtcAgent) -> Bool

Check whether a poller with the given name is registered with the agent.

# Examples
```julia
if :my_poller in agent
    println("Poller is registered")
end
```
"""
function Base.in(name::Symbol, agent::AbstractRtcAgent)
    return name in base(agent).poller_loop
end

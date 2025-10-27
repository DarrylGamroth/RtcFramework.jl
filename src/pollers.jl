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
    PollerRegistry

Internal structure for managing pollers with deferred add/remove operations.
Pollers can safely request add/remove during iteration without breaking the loop.

# Fields
- `pollers::Vector{PollerConfig}`: Current active pollers (sorted by priority)
- `add::Vector{PollerConfig}`: Buffer for pollers to add after iteration
- `remove::Vector{Symbol}`: Names queued for removal after iteration
"""
struct PollerRegistry
    pollers::Vector{PollerConfig}
    add::Vector{PollerConfig}
    remove::Vector{Symbol}
end

function PollerRegistry()
    pollers = Vector{PollerConfig}()
    add = Vector{PollerConfig}()
    remove = Vector{Symbol}()
    @static if VERSION >= v"1.11"
        sizehint!(pollers, 10; shrink=false)
        sizehint!(add, 10; shrink=false)
        sizehint!(remove, 10; shrink=false)
    else
        sizehint!(pollers, 10)
        sizehint!(add, 10)
        sizehint!(remove, 10)
    end
    return PollerRegistry(pollers, add, remove)
end

# =============================================================================
# Collections Interface for PollerRegistry
# =============================================================================

"""
Implement the collections interface for PollerRegistry.
Allows iteration, length queries, and indexed access to active pollers.
"""

# Iteration interface - iterate over active pollers only
Base.iterate(registry::PollerRegistry) = iterate(registry.pollers)
Base.iterate(registry::PollerRegistry, state) = iterate(registry.pollers, state)

# Length and size
Base.length(registry::PollerRegistry) = length(registry.pollers)
Base.size(registry::PollerRegistry) = (length(registry.pollers),)

# Element type
Base.eltype(::Type{PollerRegistry}) = PollerConfig

# Indexed access - read-only access to active pollers
Base.getindex(registry::PollerRegistry, i::Int) = registry.pollers[i]

# Keys for dictionary-like access (1-based indexing)
Base.keys(registry::PollerRegistry) = keys(registry.pollers)
Base.firstindex(registry::PollerRegistry) = 1
Base.lastindex(registry::PollerRegistry) = length(registry.pollers)

# Check if empty
Base.isempty(registry::PollerRegistry) = isempty(registry.pollers)

# Empty the collection
function Base.empty!(registry::PollerRegistry)
    empty!(registry.add)
    empty!(registry.remove)
    empty!(registry.pollers)
    return registry
end

# Membership test - check if poller name exists
Base.in(name::Symbol, registry::PollerRegistry) = any(c -> c.name === name, registry.pollers)

# Built-in poller priorities (internal constants, not exported)
const PRIORITY_INPUT = 10              # Input stream polling
const PRIORITY_PROPERTY = 50           # Property publishing
const PRIORITY_TIMER = 75              # Timer events
const PRIORITY_CONTROL = 200           # Control messages

# =============================================================================
# Internal PollerRegistry Operations
# =============================================================================

"""
    request_add!(registry::PollerRegistry, config::PollerConfig)

Request to add a poller after the current poll iteration completes.
Safe to call from within a poller function.

Throws `ArgumentError` if a poller with the same name is already registered or
queued for addition. Names slated for removal are allowed (supports unregister
then register in the same cycle).
"""
function request_add!(registry::PollerRegistry, config::PollerConfig)
    # Check for duplicates in pending additions
    for c in registry.add
        if c.name === config.name
            throw(ArgumentError("Poller name $(config.name) already registered"))
        end
    end

    # Allow re-registration if name is queued for removal
    if config.name in registry.remove
        push!(registry.add, config)
        return
    end

    # Check for duplicates in active pollers
    for c in registry.pollers
        if c.name === config.name
            throw(ArgumentError("Poller name $(config.name) already registered"))
        end
    end

    push!(registry.add, config)
end

"""
    request_remove!(registry::PollerRegistry, name::Symbol)

Request to remove a poller after the current poll iteration completes.
Safe to call from within a poller function.
"""
function request_remove!(registry::PollerRegistry, name::Symbol)
    # Cancel pending additions with the same name before queueing removal.
    for (i, config) in Iterators.reverse(pairs(registry.add))
        if config.name === name
            deleteat!(registry.add, i)
            return
        end
    end

    if name in registry.remove
        return
    end

    push!(registry.remove, name)
end

"""
    apply_poller_changes!(registry::PollerRegistry)

Apply pending add/remove operations to the poller list.
Called internally after each poll iteration.

# Algorithm
1. Remove pollers with names queued in remove (order-preserving filter)
2. Insert queued pollers into the sorted list using binary search
3. Clear buffers
"""
function apply_poller_changes!(registry::PollerRegistry)
    pollers = registry.pollers

    # Remove requested pollers (order-preserving)
    remove = registry.remove
    if !isempty(remove)
        filter!(pollers) do config
            !(config.name in remove)
        end
        empty!(remove)
    end

    # Add new pollers
    add = registry.add
    if !isempty(add)
        for config in add
            # Preserve FIFO order for identical priorities by inserting after
            # the last poller with the same priority.
            priorities = [c.priority for c in pollers]
            insert_at = searchsortedlast(priorities, config.priority)
            insert!(pollers, insert_at + 1, config)
        end
        empty!(add)
    end
end

"""
    poll_pollers!(registry::PollerRegistry, agent::AbstractRtcAgent) -> Int

Execute a single poll cycle across the current poller set and apply any queued
add/remove operations afterwards.
"""
@inline function poll_pollers!(registry::PollerRegistry, agent::AbstractRtcAgent)
    pollers = registry.pollers
    work_count = 0

    # Structural changes are deferred via the add/remove buffers.
    @inbounds for i in 1:length(pollers)
        work_count += pollers[i].poll_fn(agent)
    end

    apply_poller_changes!(registry)
    return work_count
end

# =============================================================================
# Public API
# =============================================================================

"""
    register_poller!(poll_fn, registry::PollerRegistry, name::Symbol, priority::Int)

Register a poller function directly with a PollerRegistry at the specified priority level.
Lower priority values are polled first (0 = highest priority).

Pollers with the same priority execute in registration order (FIFO) and each
poller name must be unique. Attempting to register a duplicate name throws an
`ArgumentError`.

**Note**: Registration is deferred and applied after the current poll cycle completes.
This makes it safe to register pollers from within other pollers.

# Arguments
- `poll_fn`: Function with signature `(agent::AbstractRtcAgent) -> Int`
- `registry`: The PollerRegistry to register with
- `name`: Required identifier for the poller
- `priority`: Priority level as Int (built-in pollers use 10, 50, 75, 200)

# Examples
```julia
registry = PollerRegistry()
register_poller!(my_poll_fn, registry, :custom_sensor, 25)
```
"""
function register_poller!(poll_fn, registry::PollerRegistry, name::Symbol, priority::Int)
    # Wrap function for type stability
    wrapped_fn = PollerFunction(poll_fn)
    config = PollerConfig(wrapped_fn, priority, name)

    # Defer the add operation
    request_add!(registry, config)
end

"""
    register_poller!(poll_fn, agent::AbstractRtcAgent, name::Symbol, priority::Int)

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
- `name`: Required identifier for the poller
- `priority`: Priority level as Int (built-in pollers use 10, 50, 75, 200)

# Examples
```julia
# Register a custom poller with high priority (between input=10 and property=50)
register_poller!(my_custom_poll_fn, agent, :custom_sensor, 25)

# Register with inline function at normal priority
register_poller!(agent, :my_poller, 100) do agent
    # Poll logic here
    return work_count
end

# Register multiple pollers at same priority (execute in registration order)
register_poller!(poll_a, agent, :poller_a, 100)  # Runs first
register_poller!(poll_b, agent, :poller_b, 100)  # Runs second
```
"""
function register_poller!(poll_fn, agent::AbstractRtcAgent, name::Symbol, priority::Int)
    register_poller!(poll_fn, base(agent).poller_registry, name, priority)
end

"""
    unregister_poller!(registry::PollerRegistry, name::Symbol)

Unregister a poller by name from a PollerRegistry.

**Note**: Removal is deferred and applied after the current poll cycle completes.
This makes it safe to unregister pollers from within other pollers.

If the poller is not found, this function does nothing (idempotent).

# Examples
```julia
unregister_poller!(registry, :my_custom_poller)
```
"""
function unregister_poller!(registry::PollerRegistry, name::Symbol)
    # Cancel any pending addition first
    for (i, config) in Iterators.reverse(pairs(registry.add))
        if config.name === name
            deleteat!(registry.add, i)
            return
        end
    end

    if findfirst(c -> c.name === name, registry.pollers) !== nothing
        request_remove!(registry, name)
    end
    
    return
end

"""
    unregister_poller!(agent::AbstractRtcAgent, name::Symbol)

Unregister a poller by name from an agent.

**Note**: Removal is deferred and applied after the current poll cycle completes.
This makes it safe to unregister pollers from within other pollers.

If the poller is not found, this function does nothing (idempotent).

# Examples
```julia
unregister_poller!(agent, :my_custom_poller)
```
"""
function unregister_poller!(agent::AbstractRtcAgent, name::Symbol)
    unregister_poller!(base(agent).poller_registry, name)
end

"""
    clear_pollers!(registry::PollerRegistry) -> Int

Remove all pollers from a PollerRegistry immediately.

**Note**: Unlike register/unregister, this operation is immediate.

# Returns
The number of pollers that were removed.
"""
function clear_pollers!(registry::PollerRegistry)
    count = length(registry)
    empty!(registry)

    return count
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
    clear_pollers!(base(agent).poller_registry)
end

"""
    pollers(agent::AbstractRtcAgent) -> PollerRegistry

Get the poller registry for the agent. The returned PollerRegistry implements the
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
pollers(agent::AbstractRtcAgent) = base(agent).poller_registry

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
    return name in base(agent).poller_registry
end

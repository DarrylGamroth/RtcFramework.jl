@abstracthsmdef AbstractRtcAgent

"""
    base(agent::AbstractRtcAgent)

Get the agent's BaseRtcAgent instance.

# Example
```julia
@hsmdef mutable struct MyServiceAgent{T<:BaseRtcAgent} <: AbstractRtcAgent
    base::T
    # ... service fields ...
end

# Implement required accessor
RtcFramework.base(agent::MyServiceAgent) = agent.base
```
"""
function base end

"""
    properties(agent::AbstractRtcAgent)

Get the agent's property store.

Convenience accessor for service code. Framework code should use `base(agent).properties`.

# Example
```julia
# In service code
properties(agent)[:SensorValue] = 42.0
config = properties(agent)[:MaxSpeed]
```
"""
properties(agent::AbstractRtcAgent) = base(agent).properties

"""
    timers(agent::AbstractRtcAgent)

Get the agent's timer system.

Convenience accessor for service code. Framework code should use `base(agent).timers`.

# Example
```julia
# In service code
timer_system = timers(agent)
schedule!(timer_system, 1_000_000_000, :OneSecondTimer)
```
"""
timers(agent::AbstractRtcAgent) = base(agent).timers

"""
    pollers(agent::AbstractRtcAgent) -> PollerRegistry

Get the agent's poller registry.

The returned PollerRegistry implements the Julia collections interface, allowing 
iteration, length queries, membership tests, etc.

Convenience accessor for service code. Framework code should use `base(agent).poller_registry`.

# Examples
```julia
# Register and unregister pollers
register!(my_fn, pollers(agent), :my_poller, 100)
unregister!(pollers(agent), :my_poller)

# Clear all pollers
empty!(pollers(agent))

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
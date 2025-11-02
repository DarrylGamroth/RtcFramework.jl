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
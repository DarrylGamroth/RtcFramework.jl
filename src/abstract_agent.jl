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
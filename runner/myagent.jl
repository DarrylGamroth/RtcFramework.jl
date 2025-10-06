@hsmdef mutable struct MyAgent{T<:RtcFramework.BaseRtcAgent} <: RtcFramework.AbstractRtcAgent
    base::T
end

RtcFramework.base(agent::MyAgent) = agent.base

@hsmdef mutable struct RtcAgent{T<:RtcFramework.BaseRtcAgent} <: RtcFramework.AbstractRtcAgent
    base::T
end

RtcFramework.base(agent::RtcAgent) = agent.base

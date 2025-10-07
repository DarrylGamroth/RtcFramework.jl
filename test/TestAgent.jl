"""
TestAgent module - provides a minimal agent implementation for testing RtcFramework.
"""
module TestAgent

using RtcFramework
using StaticKV
using Clocks
using Hsm
using Logging  # Needed for @base_properties macro expansion

# Define test properties using the framework's macro
@kvstore Properties begin
    @base_properties

    # Additional test properties
    TestMatrix::Array{Float32,3} => (
        rand(Float32, 10, 5, 2)
    )
    TestValue::Int64 => 42
    TestString::String => "test"
end

# Define the test agent
@hsmdef mutable struct RtcAgent{T<:RtcFramework.BaseRtcAgent} <: RtcFramework.AbstractRtcAgent
    base::T
end

# Implement required base accessor
RtcFramework.base(agent::RtcAgent) = agent.base

# Export for test usage
export Properties, RtcAgent

end # module TestAgent

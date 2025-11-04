module RtcFramework

using Aeron
using Agent
using Clocks
using EnumX
using FunctionWrappers: FunctionWrapper
using Hsm
using Logging
using SnowflakeId
using SpidersMessageCodecs
using SpidersFragmentFilters
using StaticKV
using WrappedUnions
using UnsafeArrays

include("Timers/Timers.jl")
using .Timers

const DEFAULT_INPUT_FRAGMENT_COUNT_LIMIT = 10
const DEFAULT_CONTROL_FRAGMENT_COUNT_LIMIT = 1

include("exceptions.jl")
include("counters.jl")
include("property_utilities.jl")
include("abstract_agent.jl")
include("pollers.jl")
include("communication_resources.jl")
include("adapters/adapters.jl")
include("proxies/proxies.jl")
include("states/states.jl")
include("agent.jl")
include("publishing.jl")
include("property_registration.jl")
include("dispatch.jl")
include("message_handling.jl")
include("precompile.jl")

# Exports

# Counters
export Counters, add_counter

# Property system
export @base_properties
export GCStats
export PropertyError, PropertyNotFoundError, EnvironmentVariableError

# Poller system
export pollers
export PollerFunction, PollerConfig, PollerRegistry
export register!, unregister!  # For pollers only

# Core types
export AbstractRtcAgent, BaseRtcAgent, base
export properties, timers, counters, comms

# Communication infrastructure
export CommunicationResources
export PublicationConfig
export PublishStrategy, OnUpdate, Periodic, Scheduled, RateLimited

# Timer infrastructure
export PolledTimer, schedule!, schedule_at!, cancel!

# Property publication registration
export register_property!, unregister_property!, isregistered_property

# High-level convenience methods
export publish_status_event, publish_state_change, publish_event_response
export publish_property, dispatch!

# Re-export from StaticKV for service convenience
export @kvstore, AbstractStaticKV

end # module RtcFramework

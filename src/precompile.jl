# Precompile statements for RtcFramework.jl
# This file contains precompile directives for hot path functions and critical types
# to reduce first-time execution latency and improve runtime performance.

# Note: This file should be included after all types are defined
function _precompile_rtcframework()
    # Core concrete types used throughout the system
    ClockType = CachedEpochClock{EpochClock}
    PropertiesType = AbstractStaticKV  # Will be concrete type from user's @kvstore
    IdGenType = SnowflakeIdGenerator{ClockType}
    TimerType = PolledTimer{ClockType,Symbol}
    BaseAgentType = BaseRtcAgent{ClockType,PropertiesType,IdGenType,TimerType}

    # =============================================================================
    # Core Type Construction
    # =============================================================================

    # BaseRtcAgent construction
    precompile(Tuple{typeof(BaseRtcAgent),CommunicationResources,PropertiesType,ClockType})
    precompile(Tuple{typeof(BaseRtcAgent),CommunicationResources,PropertiesType})

    # Property access (generic StaticKV operations)
    precompile(Tuple{typeof(getindex),PropertiesType,Symbol})
    precompile(Tuple{typeof(setindex!),PropertiesType,String,Symbol})
    precompile(Tuple{typeof(setindex!),PropertiesType,Int64,Symbol})
    precompile(Tuple{typeof(setindex!),PropertiesType,Float64,Symbol})
    precompile(Tuple{typeof(setindex!),PropertiesType,Bool,Symbol})
    precompile(Tuple{typeof(haskey),PropertiesType,Symbol})

    # PublicationConfig and strategy types
    precompile(Tuple{typeof(PublicationConfig),Int64,Int64,Symbol,Int,PublishStrategy,Aeron.ExclusivePublication})
    precompile(Tuple{typeof(OnUpdate)})
    precompile(Tuple{typeof(Periodic),Int64})
    precompile(Tuple{typeof(Scheduled),Int64})
    precompile(Tuple{typeof(RateLimited),Int64})

    # =============================================================================
    # Hot Path Functions - Property Publishing
    # =============================================================================

    # publish_property_update is a critical hot path
    precompile(Tuple{typeof(publish_property_update),AbstractRtcAgent,PublicationConfig})
    precompile(Tuple{typeof(property_poller),AbstractRtcAgent})

    # Strategy functions - called in every publication evaluation
    precompile(Tuple{typeof(should_publish),PublishStrategy,Int64,Int64,Int64,Int64})
    precompile(Tuple{typeof(should_publish),OnUpdateStrategy,Int64,Int64,Int64,Int64})
    precompile(Tuple{typeof(should_publish),PeriodicStrategy,Int64,Int64,Int64,Int64})
    precompile(Tuple{typeof(should_publish),ScheduledStrategy,Int64,Int64,Int64,Int64})
    precompile(Tuple{typeof(should_publish),RateLimitedStrategy,Int64,Int64,Int64,Int64})

    precompile(Tuple{typeof(next_time),PublishStrategy,Int64})
    precompile(Tuple{typeof(next_time),OnUpdateStrategy,Int64})
    precompile(Tuple{typeof(next_time),PeriodicStrategy,Int64})
    precompile(Tuple{typeof(next_time),ScheduledStrategy,Int64})
    precompile(Tuple{typeof(next_time),RateLimitedStrategy,Int64})

    # =============================================================================
    # Communication Functions - High Frequency
    # =============================================================================

    # Proxy construction
    precompile(Tuple{typeof(StatusProxy),Aeron.ExclusivePublication})
    precompile(Tuple{typeof(PropertyProxy),Vector{Aeron.ExclusivePublication}})

    # High-level publishing convenience functions
    precompile(Tuple{typeof(publish_status_event),AbstractRtcAgent,Symbol,String})
    precompile(Tuple{typeof(publish_status_event),AbstractRtcAgent,Symbol,Symbol})
    precompile(Tuple{typeof(publish_state_change),AbstractRtcAgent,Symbol})
    precompile(Tuple{typeof(publish_event_response),AbstractRtcAgent,Symbol,String})
    precompile(Tuple{typeof(publish_event_response),AbstractRtcAgent,Symbol,Symbol})
    precompile(Tuple{typeof(publish_event_response),AbstractRtcAgent,Symbol,Int64})
    precompile(Tuple{typeof(publish_event_response),AbstractRtcAgent,Symbol,Float64})
    precompile(Tuple{typeof(publish_event_response),AbstractRtcAgent,Symbol,Bool})
    precompile(Tuple{typeof(publish_property),AbstractRtcAgent,Int,Symbol,String})

    # StatusProxy publishing - scalar types
    precompile(Tuple{typeof(publish_status_event),StatusProxy,Symbol,String,String,Int64,Int64})
    precompile(Tuple{typeof(publish_status_event),StatusProxy,Symbol,Symbol,String,Int64,Int64})
    precompile(Tuple{typeof(publish_status_event),StatusProxy,Symbol,Int64,String,Int64,Int64})
    precompile(Tuple{typeof(publish_status_event),StatusProxy,Symbol,Float64,String,Int64,Int64})
    precompile(Tuple{typeof(publish_status_event),StatusProxy,Symbol,Bool,String,Int64,Int64})
    precompile(Tuple{typeof(publish_status_event),StatusProxy,Symbol,Nothing,String,Int64,Int64})

    # StatusProxy publishing - array types
    precompile(Tuple{typeof(publish_status_event),StatusProxy,Symbol,Vector{Float32},String,Int64,Int64})
    precompile(Tuple{typeof(publish_status_event),StatusProxy,Symbol,Vector{Int64},String,Int64,Int64})
    precompile(Tuple{typeof(publish_status_event),StatusProxy,Symbol,Array{Float32,3},String,Int64,Int64})

    # StatusProxy convenience functions
    precompile(Tuple{typeof(publish_state_change),StatusProxy,Symbol,String,Int64,Int64})
    precompile(Tuple{typeof(publish_event_response),StatusProxy,Symbol,String,String,Int64,Int64})
    precompile(Tuple{typeof(publish_event_response),StatusProxy,Symbol,Symbol,String,Int64,Int64})
    precompile(Tuple{typeof(publish_event_response),StatusProxy,Symbol,Int64,String,Int64,Int64})
    precompile(Tuple{typeof(publish_event_response),StatusProxy,Symbol,Float64,String,Int64,Int64})
    precompile(Tuple{typeof(publish_event_response),StatusProxy,Symbol,Bool,String,Int64,Int64})

    # PropertyProxy publishing - scalar types
    precompile(Tuple{typeof(publish_property),PropertyProxy,Int,Symbol,String,String,Int64,Int64})
    precompile(Tuple{typeof(publish_property),PropertyProxy,Int,Symbol,Symbol,String,Int64,Int64})
    precompile(Tuple{typeof(publish_property),PropertyProxy,Int,Symbol,Int64,String,Int64,Int64})
    precompile(Tuple{typeof(publish_property),PropertyProxy,Int,Symbol,Float64,String,Int64,Int64})
    precompile(Tuple{typeof(publish_property),PropertyProxy,Int,Symbol,Bool,String,Int64,Int64})
    precompile(Tuple{typeof(publish_property),PropertyProxy,Int,Symbol,Nothing,String,Int64,Int64})

    # PropertyProxy publishing - array types
    precompile(Tuple{typeof(publish_property),PropertyProxy,Int,Symbol,Vector{Float32},String,Int64,Int64})
    precompile(Tuple{typeof(publish_property),PropertyProxy,Int,Symbol,Vector{Int64},String,Int64,Int64})
    precompile(Tuple{typeof(publish_property),PropertyProxy,Int,Symbol,Array{Float32,3},String,Int64,Int64})

    # PropertyProxy with strategy evaluation
    precompile(Tuple{typeof(publish_property_update),PropertyProxy,PublicationConfig,PropertiesType,String,Int64,Int64})

    # =============================================================================
    # Aeron Communication Primitives
    # =============================================================================

    # Critical Aeron functions (from publication_helpers.jl)
    precompile(Tuple{typeof(try_claim),Aeron.ExclusivePublication,Int})
    precompile(Tuple{typeof(offer),Aeron.ExclusivePublication,Vector{UInt8}})
    precompile(Tuple{typeof(offer),Aeron.ExclusivePublication,Tuple{Vector{UInt8},Vector{UInt8}}})
    precompile(Tuple{typeof(offer),Aeron.ExclusivePublication,Tuple{Vector{UInt8},Vector{UInt8},Vector{UInt8}}})

    # =============================================================================
    # Property Management API
    # =============================================================================

    # Property registration and management
    precompile(Tuple{typeof(register!),AbstractRtcAgent,Symbol,Int,PublishStrategy})
    precompile(Tuple{typeof(unregister!),AbstractRtcAgent,Symbol,Int})
    precompile(Tuple{typeof(unregister!),AbstractRtcAgent,Symbol})
    precompile(Tuple{typeof(isregistered),AbstractRtcAgent,Symbol})
    precompile(Tuple{typeof(isregistered),AbstractRtcAgent,Symbol,Int})
    precompile(Tuple{typeof(empty!),AbstractRtcAgent})

    # =============================================================================
    # Property Value Handling - Performance Critical
    # =============================================================================

    # Decode property values from messages
    precompile(Tuple{typeof(decode_property_value),EventMessageDecoder,Type{String}})
    precompile(Tuple{typeof(decode_property_value),EventMessageDecoder,Type{Int64}})
    precompile(Tuple{typeof(decode_property_value),EventMessageDecoder,Type{Float64}})
    precompile(Tuple{typeof(decode_property_value),EventMessageDecoder,Type{Bool}})
    precompile(Tuple{typeof(decode_property_value),EventMessageDecoder,Type{Symbol}})
    precompile(Tuple{typeof(decode_property_value),EventMessageDecoder,Type{Vector{Float32}}})
    precompile(Tuple{typeof(decode_property_value),EventMessageDecoder,Type{Array{Float32,3}}})

    # Set property values
    precompile(Tuple{typeof(set_property_value!),PropertiesType,Symbol,String,Type{String}})
    precompile(Tuple{typeof(set_property_value!),PropertiesType,Symbol,Int64,Type{Int64}})
    precompile(Tuple{typeof(set_property_value!),PropertiesType,Symbol,Float64,Type{Float64}})
    precompile(Tuple{typeof(set_property_value!),PropertiesType,Symbol,Bool,Type{Bool}})
    precompile(Tuple{typeof(set_property_value!),PropertiesType,Symbol,Vector{Float32},Type{Vector{Float32}}})
    precompile(Tuple{typeof(set_property_value!),PropertiesType,Symbol,Array{Float32,3},Type{Array{Float32,3}}})

    # Property handlers
    precompile(Tuple{typeof(on_property_write),AbstractRtcAgent,Symbol,EventMessageDecoder})
    precompile(Tuple{typeof(on_property_read),AbstractRtcAgent,Symbol,EventMessageDecoder})

    # =============================================================================
    # Event Dispatch
    # =============================================================================

    # Core dispatch function with common argument types
    precompile(Tuple{typeof(dispatch!),AbstractRtcAgent,Symbol,Nothing})
    precompile(Tuple{typeof(dispatch!),AbstractRtcAgent,Symbol,EventMessageDecoder})
    precompile(Tuple{typeof(dispatch!),AbstractRtcAgent,Symbol,TensorMessageDecoder})
    precompile(Tuple{typeof(dispatch!),AbstractRtcAgent,Symbol,Int64})
    precompile(Tuple{typeof(dispatch!),AbstractRtcAgent,Symbol,String})
    precompile(Tuple{typeof(dispatch!),AbstractRtcAgent,Symbol,Exception})

    # =============================================================================
    # Agent Framework Interface
    # =============================================================================

    # Agent.jl protocol methods
    precompile(Tuple{typeof(Agent.name),AbstractRtcAgent})
    precompile(Tuple{typeof(Agent.on_start),AbstractRtcAgent})
    precompile(Tuple{typeof(Agent.on_close),AbstractRtcAgent})
    precompile(Tuple{typeof(Agent.on_error),AbstractRtcAgent,Exception})
    precompile(Tuple{typeof(Agent.do_work),AbstractRtcAgent})

    # =============================================================================
    # Adapter Construction and Operations
    # =============================================================================

    # Adapter creation
    precompile(Tuple{typeof(ControlStreamAdapter),Aeron.Subscription,AbstractRtcAgent})
    precompile(Tuple{typeof(InputStreamAdapter),Aeron.Subscription,AbstractRtcAgent})

    # Adapter polling operations
    precompile(Tuple{typeof(poll),ControlStreamAdapter,Int})
    precompile(Tuple{typeof(poll),InputStreamAdapter,Int})
    precompile(Tuple{typeof(poll),Vector{InputStreamAdapter},Int})

    # =============================================================================
    # Communication Setup/Teardown
    # =============================================================================

    # CommunicationResources operations
    precompile(Tuple{typeof(CommunicationResources),Aeron.Client,PropertiesType})
    precompile(Tuple{typeof(Base.close),CommunicationResources})
    precompile(Tuple{typeof(Base.isopen),CommunicationResources})

    # =============================================================================
    # Poller System - Type-Stable Unified Polling
    # =============================================================================

    # Poller registration and management
    precompile(Tuple{typeof(register_poller!),Function,AbstractRtcAgent,Int,Symbol})
    precompile(Tuple{typeof(unregister_poller!),AbstractRtcAgent,Symbol})
    precompile(Tuple{typeof(clear_pollers!),AbstractRtcAgent})
    precompile(Tuple{typeof(list_pollers),AbstractRtcAgent})

    # PollerConfig construction
    precompile(Tuple{typeof(PollerConfig),PollerFunction,Int,Symbol})

    # FunctionWrapper construction for pollers
    precompile(Tuple{Type{FunctionWrapper{Int,Tuple{AbstractRtcAgent}}},Function})

    # =============================================================================
    # Message Handlers and Pollers
    # =============================================================================

    # Built-in polling functions
    precompile(Tuple{typeof(input_poller),AbstractRtcAgent})
    precompile(Tuple{typeof(control_poller),AbstractRtcAgent})
    precompile(Tuple{typeof(timer_poller),AbstractRtcAgent})
    precompile(Tuple{typeof(property_poller),AbstractRtcAgent})
    
    # Built-in poller registration
    precompile(Tuple{typeof(register_builtin_pollers!),AbstractRtcAgent})

    # =============================================================================
    # Timer System Hot Paths
    # =============================================================================

    # Timer operations - exported for extension services
    precompile(Tuple{typeof(schedule!),TimerType,Int64,Symbol})
    precompile(Tuple{typeof(schedule_at!),TimerType,Int64,Symbol})
    precompile(Tuple{typeof(cancel!),TimerType,Int64})
    precompile(Tuple{typeof(cancel!),TimerType,Symbol})
    precompile(Tuple{typeof(cancel!),TimerType})

    # Internal timer operations
    precompile(Tuple{typeof(Timers.poll),Function,TimerType,AbstractRtcAgent})
    precompile(Tuple{typeof(Timers.schedule!),TimerType,Int64,Symbol})
    precompile(Tuple{typeof(Timers.schedule_at!),TimerType,Int64,Symbol})
    precompile(Tuple{typeof(Timers.cancel!),TimerType,Int64})
    precompile(Tuple{typeof(Timers.cancel!),TimerType,Symbol})
    precompile(Tuple{typeof(Timers.cancel!),TimerType})

    # =============================================================================
    # Exception Types for Error Handling
    # =============================================================================

    # Exception construction
    precompile(Tuple{typeof(AgentStateError),Symbol,String})
    precompile(Tuple{typeof(AgentCommunicationError),String})
    precompile(Tuple{typeof(AgentConfigurationError),String})
    precompile(Tuple{typeof(PublicationError),String,Symbol})
    precompile(Tuple{typeof(PublicationFailureError),String,Int})
    precompile(Tuple{typeof(ClaimBufferError),String,Int,Int,Int})
    precompile(Tuple{typeof(PublicationBackPressureError),String,Int,Int})
    precompile(Tuple{typeof(StreamNotFoundError),String,Int})
    precompile(Tuple{typeof(CommunicationNotInitializedError),String})
    precompile(Tuple{typeof(PropertyNotFoundError),Symbol})
    precompile(Tuple{typeof(EnvironmentVariableError),String})

    # Exception display
    precompile(Tuple{typeof(Base.showerror),IO,AgentStateError})
    precompile(Tuple{typeof(Base.showerror),IO,AgentCommunicationError})
    precompile(Tuple{typeof(Base.showerror),IO,AgentConfigurationError})
    precompile(Tuple{typeof(Base.showerror),IO,PublicationError})
    precompile(Tuple{typeof(Base.showerror),IO,ClaimBufferError})
    precompile(Tuple{typeof(Base.showerror),IO,PublicationBackPressureError})

    # =============================================================================
    # WrappedUnions Operations (Critical for Performance)
    # =============================================================================

    # PublishStrategy operations
    precompile(Tuple{typeof(WrappedUnions.unwrap),PublishStrategy})

    # =============================================================================
    # Message Codec Operations
    # =============================================================================

    # Message encoding/decoding - frequently used in hot paths
    precompile(Tuple{typeof(SpidersMessageCodecs.EventMessageEncoder),Vector{UInt8}})
    precompile(Tuple{typeof(SpidersMessageCodecs.EventMessageDecoder),Vector{UInt8}})
    precompile(Tuple{typeof(SpidersMessageCodecs.EventMessageDecoder),UnsafeArrays.UnsafeArray{UInt8}})
    precompile(Tuple{typeof(SpidersMessageCodecs.TensorMessageEncoder),Vector{UInt8}})
    precompile(Tuple{typeof(SpidersMessageCodecs.TensorMessageDecoder),Vector{UInt8}})
    precompile(Tuple{typeof(SpidersMessageCodecs.TensorMessageDecoder),UnsafeArrays.UnsafeArray{UInt8}})

    # Message header operations
    precompile(Tuple{typeof(SpidersMessageCodecs.header),EventMessageEncoder})
    precompile(Tuple{typeof(SpidersMessageCodecs.header),EventMessageDecoder})
    precompile(Tuple{typeof(SpidersMessageCodecs.header),TensorMessageEncoder})
    precompile(Tuple{typeof(SpidersMessageCodecs.header),TensorMessageDecoder})

    # Common message field operations
    precompile(Tuple{typeof(SpidersMessageCodecs.timestampNs!),MessageHeader,Int64})
    precompile(Tuple{typeof(SpidersMessageCodecs.correlationId!),MessageHeader,Int64})
    precompile(Tuple{typeof(SpidersMessageCodecs.tag!),MessageHeader,String})
    precompile(Tuple{typeof(SpidersMessageCodecs.key!),EventMessageEncoder,Symbol})
    precompile(Tuple{typeof(SpidersMessageCodecs.key),EventMessageDecoder,Type{Symbol}})

    # =============================================================================
    # Clock Operations (High Frequency)
    # =============================================================================

    # Clock operations used in every work iteration
    precompile(Tuple{typeof(Clocks.fetch!),ClockType})
    precompile(Tuple{typeof(Clocks.time_nanos),ClockType})
    precompile(Tuple{typeof(Clocks.time_micros),ClockType})

    # ID generation
    precompile(Tuple{typeof(SnowflakeId.next_id),IdGenType})

    # =============================================================================
    # Utility Functions
    # =============================================================================

    # Base accessor
    precompile(Tuple{typeof(base),AbstractRtcAgent})
    precompile(Tuple{typeof(base),BaseAgentType})

    # Convenience accessors for service code
    precompile(Tuple{typeof(properties),AbstractRtcAgent})
    precompile(Tuple{typeof(timers),AbstractRtcAgent})

    nothing
end

# Execute precompilation
_precompile_rtcframework()

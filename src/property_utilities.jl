"""
Property system utilities for RTC framework.

Provides the @base_properties macro for generating standard RTC service properties
with dynamic URI/stream configuration from environment variables.
"""

"""
    GCStats

Wrapper struct for Base.GC_Num with abbreviated field names to fit SBE constraints.
Field names are shortened from Base.GC_Num to stay within SBE key field length limits.
"""
struct GCStats
    allocd::Int64
    deferred_alloc::Int64
    freed::Int64
    malloc::Int64
    realloc::Int64
    poolalloc::Int64
    bigalloc::Int64
    freecall::Int64
    total_time::Int64
    total_allocd::Int64
    collect::UInt64
    pause::Int32
    full_sweep::Int32
    max_pause::Int64
    max_memory::Int64
    safepoint_time::Int64  # was: time_to_safepoint
    max_safepoint_time::Int64  # was: max_time_to_safepoint
    total_safepoint_time::Int64  # was: total_time_to_safepoint
    sweep_time::Int64
    mark_time::Int64
    stack_sweep_time::Int64  # was: stack_pool_sweep_time
    total_sweep_time::Int64
    sweep_page_walk_time::Int64  # was: total_sweep_page_walk_time
    sweep_madvise_time::Int64  # was: total_sweep_madvise_time
    sweep_free_malloc_time::Int64  # was: total_sweep_free_mallocd_memory_time
    total_mark_time::Int64
    total_stack_sweep_time::Int64  # was: total_stack_pool_sweep_time
    last_full_sweep::Int64
    last_inc_sweep::Int64  # was: last_incremental_sweep
end

"""
    GCStats(gc_num::Base.GC_Num)

Convert Base.GC_Num to GCStats with abbreviated field names.
"""
function GCStats(gc_num::Base.GC_Num)
    GCStats(
        gc_num.allocd,
        gc_num.deferred_alloc,
        gc_num.freed,
        gc_num.malloc,
        gc_num.realloc,
        gc_num.poolalloc,
        gc_num.bigalloc,
        gc_num.freecall,
        gc_num.total_time,
        gc_num.total_allocd,
        gc_num.collect,
        gc_num.pause,
        gc_num.full_sweep,
        gc_num.max_pause,
        gc_num.max_memory,
        gc_num.time_to_safepoint,
        gc_num.max_time_to_safepoint,
        gc_num.total_time_to_safepoint,
        gc_num.sweep_time,
        gc_num.mark_time,
        gc_num.stack_pool_sweep_time,
        gc_num.total_sweep_time,
        gc_num.total_sweep_page_walk_time,
        gc_num.total_sweep_madvise_time,
        gc_num.total_sweep_free_mallocd_memory_time,
        gc_num.total_mark_time,
        gc_num.total_stack_pool_sweep_time,
        gc_num.last_full_sweep,
        gc_num.last_incremental_sweep
    )
end

"""
    @base_properties

Generate all standard RTC framework properties that every service needs.

This macro expands to include:
- Service identity: Name, NodeId
- Communication config: StatusURI/StreamID, ControlURI/StreamID/Filter
- Timing config: HeartbeatPeriodNs, LateMessageThresholdNs
- Runtime management: LogLevel, GCBytes, GCEnable, GCLogging
- Dynamic data streams: Generated from SUB_DATA_URI_* and PUB_DATA_URI_* environment variables

Services should use this macro in their @kvstore property definition and add
only service-specific properties afterward.

# Example
```julia
@kvstore MyServiceProperties begin
    @base_properties

    # Service-specific properties only
    Temperature::Float32 => (0.0f0;)
    Threshold::Float32 => (100.0f0;)
end
```
"""
macro base_properties()
    # Generate SUB_DATA_URI keys inline
    sub_keys = []
    sub_connection_count = 0

    for (key, value) in ENV
        if startswith(key, "SUB_DATA_URI_")
            sub_connection_count += 1
            idx = parse(Int, replace(key, "SUB_DATA_URI_" => ""))
            uri_field = Symbol("SubDataURI$(idx)")
            stream_field = Symbol("SubDataStreamID$(idx)")

            push!(sub_keys, :(
                $uri_field::String => (
                    $value;
                    access = AccessMode.READABLE
                )
            ))

            stream_key = "SUB_DATA_STREAM_$(idx)"
            if haskey(ENV, stream_key)
                stream_value = parse(Int, ENV[stream_key])
                push!(sub_keys, :(
                    $stream_field::Int64 => (
                        $stream_value;
                        access = AccessMode.READABLE
                    )
                ))
            end
        end
    end

    push!(sub_keys, :(
        SubDataConnectionCount::Int64 => (
            $sub_connection_count;
            access = AccessMode.READABLE
        )
    ))

    # Generate PUB_DATA_URI keys inline
    pub_keys = []
    pub_connection_count = 0

    for (key, value) in ENV
        if startswith(key, "PUB_DATA_URI_")
            pub_connection_count += 1
            idx = parse(Int, replace(key, "PUB_DATA_URI_" => ""))
            uri_field = Symbol("PubDataURI$(idx)")
            stream_field = Symbol("PubDataStreamID$(idx)")

            push!(pub_keys, :(
                $uri_field::String => (
                    $value;
                    access = AccessMode.READABLE
                )
            ))

            stream_key = "PUB_DATA_STREAM_$(idx)"
            if haskey(ENV, stream_key)
                stream_value = parse(Int, ENV[stream_key])
                push!(pub_keys, :(
                    $stream_field::Int64 => (
                        $stream_value;
                        access = AccessMode.READABLE
                    )
                ))
            end
        end
    end

    push!(pub_keys, :(
        PubDataConnectionCount::Int64 => (
            $pub_connection_count;
            access = AccessMode.READABLE
        )
    ))

    # Generate GC statistics fields as individual properties using GCStats struct
    gc_keys = []
    for fname in fieldnames(RtcFramework.GCStats)
        field_type = fieldtype(RtcFramework.GCStats, fname)
        prop_name = Symbol("GC_", fname)
        default_val = zero(field_type)
        push!(gc_keys, :(
            $prop_name::$field_type => $default_val
        ))
    end

    # Generate performance counter properties from COUNTER_METADATA
    counter_keys = []
    for metadata in RtcFramework.COUNTER_METADATA
        prop_name = Symbol(metadata.label)
        push!(counter_keys, :(
            $prop_name::Int64 => (
                0;
                access = AccessMode.READABLE
            )
        ))
    end

    return esc(quote
        Name::String => (
            get(ENV, "BLOCK_NAME") do
                throw(RtcFramework.EnvironmentVariableError("BLOCK_NAME"))
            end;
            access = AccessMode.READABLE
        )
        NodeId::Int64 => (
            parse(Int64, get(ENV, "BLOCK_ID") do
                throw(RtcFramework.EnvironmentVariableError("BLOCK_ID"))
            end);
            access = AccessMode.READABLE
        )
        StatusURI::String => (
            get(ENV, "STATUS_URI") do
                throw(RtcFramework.EnvironmentVariableError("STATUS_URI"))
            end;
            access = AccessMode.READABLE
        )
        StatusStreamID::Int64 => (
            parse(Int64, get(ENV, "STATUS_STREAM_ID") do
                throw(RtcFramework.EnvironmentVariableError("STATUS_STREAM_ID"))
            end);
            access = AccessMode.READABLE
        )
        ControlURI::String => (
            get(ENV, "CONTROL_URI") do
                throw(RtcFramework.EnvironmentVariableError("CONTROL_URI"))
            end;
            access = AccessMode.READABLE
        )
        ControlStreamID::Int64 => (
            parse(Int64, get(ENV, "CONTROL_STREAM_ID") do
                throw(RtcFramework.EnvironmentVariableError("CONTROL_STREAM_ID"))
            end);
            access = AccessMode.READABLE
        )
        ControlFilter::String => (
            get(ENV, "CONTROL_FILTER", nothing);
            access = AccessMode.READABLE
        )
        HeartbeatPeriodNs::Int64 => (
            parse(Int64, get(ENV, "HEARTBEAT_PERIOD_NS", "10000000000"))
        )
        LateMessageThresholdNs::Int64 => (
            parse(Int64, get(ENV, "LATE_MESSAGE_THRESHOLD_NS", "1000000000"));
            access = AccessMode.READABLE
        )
        LogLevel::Symbol => (
            Symbol(get(ENV, "LOG_LEVEL", "Debug"));
            on_set = (obj, name, val) -> begin
                if !isdefined(Logging, val)
                    throw(ArgumentError("Invalid log level: $val"))
                end

                level = getfield(Logging, val)
                Logging.disable_logging(level)

                return val
            end
        )
        TriggerGC::Bool => (
            false;
            access = AccessMode.WRITABLE,
            on_set=(obj, name, val) -> (GC.gc(val); val),
        )
        GCStatsPeriodNs::Int64 => (
            parse(Int64, get(ENV, "GC_STATS_PERIOD_NS", "10000000000"))
        )
                
        GCEnable::Bool => (
            true;
            on_set=(obj, name, val) -> (GC.enable(val); val),
        )
        GCLogging::Bool => (
            parse(Bool, get(ENV, "GC_LOGGING", "false"));
            on_set=(obj, name, val) -> (GC.enable_logging(val); val),
            on_get=(obj, name, val) -> GC.logging_enabled()
        )

        $(gc_keys...)
        
        # Performance counters (auto-generated from COUNTER_METADATA)
        # Minimal set: TotalDutyCycles, TotalWorkDone, PropertiesPublished
        $(counter_keys...)
        
        # Derived metrics (calculated periodically from counters)
        # MessageRateHz = property publication rate (from PROPERTIES_PUBLISHED counter)
        # WorkRateHz = work processing rate (from TOTAL_WORK_DONE counter)
        MessageRateHz::Float64 => (
            0.0;
            access = AccessMode.READABLE
        )
        WorkRateHz::Float64 => (
            0.0;
            access = AccessMode.READABLE
        )
        
        # Stats update period (5 seconds default)
        StatsPeriodNs::Int64 => (
            parse(Int64, get(ENV, "STATS_PERIOD_NS", "5000000000"))
        )
        
        $(sub_keys...)
        $(pub_keys...)
    end)
end

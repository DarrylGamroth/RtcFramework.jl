"""
Property system utilities for RTC framework.

Provides the @base_properties macro for generating standard RTC service properties
with dynamic URI/stream configuration from environment variables.
"""

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
        GCNum::Base.GC_Num => (
            Base.gc_num();
            access = AccessMode.READABLE
        )
        GCDiff::Base.GC_Diff => (
            ;
            access = AccessMode.READABLE
        )
        GCEnable::Bool => (
            true;
            on_set=(obj, name, val) -> GC.enable(val),
        )
        GCLogging::Bool => (
            parse(Bool, get(ENV, "GC_LOGGING", "false"));
            on_set=(obj, name, val) -> (GC.enable_logging(val); val),
            on_get=(obj, name, val) -> GC.logging_enabled()
        )

        $(sub_keys...)
        $(pub_keys...)
    end)
end

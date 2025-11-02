# Top state handlers
# Handles top-level events like heartbeat, reset, errors, and system commands

@statedef AbstractRtcAgent :Top

@on_initial function (sm::AbstractRtcAgent, ::Top)
    Hsm.transition!(sm, :Ready)
end

@on_entry function (sm::AbstractRtcAgent, ::Top)
    b = base(sm)

    # Create control stream adapter
    b.control_adapter = ControlStreamAdapter(
        b.comms.control_stream,
        sm
    )

    # Create input stream adapters
    for input_stream in b.comms.input_streams
        push!(b.input_adapters, InputStreamAdapter(input_stream, sm))
    end

    # Create proxy instances
    b.status_proxy = StatusProxy(b.comms.status_stream)
    b.property_proxy = PropertyProxy(b.comms.output_streams)

    # Register pollers

    # Input stream polling
    register_poller!(input_poller, sm, :input_streams, PRIORITY_INPUT)

    # Property publishing
    register_poller!(property_poller, sm, :properties, PRIORITY_PROPERTY)

    # Timer events
    register_poller!(timer_poller, sm, :timers, PRIORITY_TIMER)

    # Control stream polling (lowest priority of built-ins)
    register_poller!(control_poller, sm, :control_stream, PRIORITY_CONTROL)

    # Schedule recurring timers
    schedule!(b.timers, 0, :Heartbeat)
    schedule!(b.timers, 0, :GCStats)
    schedule!(b.timers, 0, :StatsUpdate)
end

@on_exit function (sm::AbstractRtcAgent, ::Top)
    b = base(sm)

    # Cancel all scheduled timers
    cancel!(b.timers)

    # Clear all pollers
    clear_pollers!(sm)

    # Clear the input adapters
    empty!(b.input_adapters)

    # Empty the property registry
    empty!(b.property_registry)

    # Clear adapters and proxies
    b.property_proxy = nothing
    b.status_proxy = nothing
    b.control_adapter = nothing
end

@on_event function (sm::AbstractRtcAgent, state::Top, ::Reset, _)
    Hsm.transition!(sm, state)
end

@on_event function (sm::AbstractRtcAgent, ::Top, event::Heartbeat, now::Int64)
    publish_event_response(sm, event, Hsm.current(sm))

    # Reschedule the next heartbeat
    b = base(sm)
    next_heartbeat_time = now + b.properties[:HeartbeatPeriodNs]
    schedule_at!(b.timers, next_heartbeat_time, :Heartbeat)

    return Hsm.EventHandled
end

@on_event function (sm::AbstractRtcAgent, ::Top, ::GCStats, now::Int64)
    b = base(sm)
    gc_stats = RtcFramework.GCStats(Base.gc_num())

    # Use StaticKV.value! to bypass READABLE access control (internal API)
    for fname in fieldnames(RtcFramework.GCStats)
        prop_name = Symbol("GC_", fname)
        prop_value = getfield(gc_stats, fname)
        StaticKV.value!(b.properties, prop_value, prop_name)
    end

    # Reschedule the next GCStats event
    next_gc_time = now + b.properties[:GCStatsPeriodNs]
    schedule_at!(b.timers, next_gc_time, :GCStats)

    return Hsm.EventHandled
end

@on_event function (sm::AbstractRtcAgent, ::Top, ::StatsUpdate, now::Int64)
    b = base(sm)
    counters = b.counters
    props = b.properties

    # Calculate elapsed time using cached clock (zero overhead)
    elapsed_ns = now - b.last_stats_time
    elapsed_s = elapsed_ns / 1_000_000_000.0

    msg_count = get_counter(counters, PROPERTIES_PUBLISHED)
    work_count = get_counter(counters, TOTAL_WORK_DONE)
    msg_delta = msg_count - b.last_msg_count
    work_delta = work_count - b.last_work_count

    # Use StaticKV.value! to bypass READABLE access control (internal API)
    StaticKV.value!(props, msg_delta / elapsed_s, :MessageRateHz)
    StaticKV.value!(props, work_delta / elapsed_s, :WorkRateHz)
    StaticKV.value!(props, get_counter(counters, TOTAL_DUTY_CYCLES), :TotalDutyCycles)
    StaticKV.value!(props, work_count, :TotalWorkDone)
    StaticKV.value!(props, msg_count, :PropertiesPublished)

    # Save state for next delta calculation
    b.last_stats_time = now
    b.last_msg_count = msg_count
    b.last_work_count = work_count

    # Reschedule
    next_stats_time = now + props[:StatsPeriodNs]
    schedule_at!(b.timers, next_stats_time, :StatsUpdate)

    return Hsm.EventHandled
end

@on_event function (sm::AbstractRtcAgent, ::Top, event::Error, (source_event, exception))
    publish_event_response(sm, event, exception)
    @error "Exception caught during event dispatch:" source_event exception = (exception, catch_backtrace())
    return Hsm.EventHandled

    # Transition to Error state
    # Hsm.transition!(sm, :Error)
end

@on_event function (sm::AbstractRtcAgent, ::Top, ::AgentOnClose, _)
    Hsm.transition!(sm, :Exit)
end

@on_event function (sm::AbstractRtcAgent, ::Top, event::State, _)
    publish_event_response(sm, event, Hsm.current(sm))
    return Hsm.EventHandled
end

@on_event function (sm::AbstractRtcAgent, ::Top, ::Exit, _)
    Hsm.transition!(sm, :Exit)
end

@on_event function (sm::AbstractRtcAgent, ::Top, event::LateMessage, _)
    publish_event_response(sm, event, nothing)
    return Hsm.EventHandled
end

@on_event function (sm::AbstractRtcAgent, ::Top, ::Properties, message)
    props = base(sm).properties
    for name in keynames(props)
        if is_readable(props, name)
            on_property_read(sm, name, message)
        end
    end
    return Hsm.EventHandled
end

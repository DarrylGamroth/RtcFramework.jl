# Top state handlers
# Handles top-level events like heartbeat, reset, errors, and system commands

@statedef AbstractRtcAgent :Top

@on_entry function (sm::AbstractRtcAgent, state::Top)
    schedule!(base(sm).timers, 0, :Heartbeat)
end

@on_exit function (sm::AbstractRtcAgent, state::Top)
    cancel!(base(sm).timers)
end

@on_initial function (sm::AbstractRtcAgent, ::Top)
    Hsm.transition!(sm, :Ready)
end

@on_event function (sm::AbstractRtcAgent, ::Top, event::Heartbeat, now::Int64)
    publish_event_response(sm, event, Hsm.current(sm))

    # Reschedule the next heartbeat
    b = base(sm)
    next_heartbeat_time = now + b.properties[:HeartbeatPeriodNs]
    schedule_at!(b.timers, next_heartbeat_time, :Heartbeat)

    return Hsm.EventHandled
end

@on_event function (sm::AbstractRtcAgent, ::Top, event::Error, (e, exception))
    publish_event_response(sm, event, exception)
    @error "Error in dispatching event $e" exception
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

@on_event function (sm::AbstractRtcAgent, ::Top, ::GC, _)
    GC.gc()
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
    for name in keynames(base(sm).properties)
        on_property_read(sm, name, message)
    end
    return Hsm.EventHandled
end

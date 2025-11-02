# Root state handlers

# Root state is implicitly defined by the HSM framework

@on_initial function (sm::AbstractRtcAgent, ::Root)
    Hsm.transition!(sm, :Startup)
end

@on_event function (sm::AbstractRtcAgent, state::Root, event::Any, message::EventMessage)
    @info "Default handler called with event: $(event)"
    if event in keynames(base(sm).properties)
        if SpidersMessageCodecs.format(message) == SpidersMessageCodecs.Format.NOTHING
            # If the message has no value, then it is a request for the current value
            on_property_read(sm, event, message)
        else
            # Otherwise it's a write request
            on_property_write(sm, event, message)
        end
        return Hsm.EventHandled
    end

    # Defer to the ancestor handler
    return Hsm.EventNotHandled
end

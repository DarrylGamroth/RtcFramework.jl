# Processing state handlers
# Handles common processing state behaviors and transitions

@statedef AbstractRtcAgent :Processing :Ready

@on_entry function (sm::AbstractRtcAgent, ::Processing)
    register_poller!(input_poller, sm, :input_streams, PRIORITY_INPUT)
end

@on_exit function (sm::AbstractRtcAgent, ::Processing)
    unregister_poller!(sm, :input_streams)
end

@on_initial function (sm::AbstractRtcAgent, ::Processing)
    Hsm.transition!(sm, :Paused)
end

@on_event function (sm::AbstractRtcAgent, ::Processing, ::Stop, _)
    Hsm.transition!(sm, :Stopped)
end

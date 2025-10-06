# Processing state handlers
# Handles common processing state behaviors and transitions

@statedef AbstractRtcAgent :Processing :Ready

@on_entry function (sm::AbstractRtcAgent, ::Processing)
    # Register properties for the agent's lifecycle
    register!(sm, :TestMatrix, 1, Periodic(1_000_000))
    GC.gc()
end

@on_exit function (sm::AbstractRtcAgent, ::Processing)
    # Clean up all property registrations when leaving processing
    unregister!(sm, :TestMatrix)
end

@on_initial function (sm::AbstractRtcAgent, ::Processing)
    Hsm.transition!(sm, :Paused)
end

@on_event function (sm::AbstractRtcAgent, ::Processing, ::Stop, _)
    Hsm.transition!(sm, :Stopped)
end

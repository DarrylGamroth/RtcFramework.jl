# Playing state handlers
# Handles events specific to the playing state

@statedef AbstractRtcAgent :Playing :Processing

@on_event function (sm::AbstractRtcAgent, ::Playing, ::Pause, _)
    Hsm.transition!(sm, :Paused)
end

@on_entry function (sm::AbstractRtcAgent, ::Playing)
    nothing
end

@on_exit function (sm::AbstractRtcAgent, ::Playing)
    nothing
end

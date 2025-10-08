# Playing state handlers
# Handles events specific to the playing state

@statedef AbstractRtcAgent :Playing :Processing

@on_event function (sm::AbstractRtcAgent, ::Playing, ::Pause, _)
    Hsm.transition!(sm, :Paused)
end

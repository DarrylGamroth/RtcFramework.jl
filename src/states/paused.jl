# Paused state handlers
# Handles events specific to the paused state

@statedef AbstractRtcAgent :Paused :Processing

@on_event function (sm::AbstractRtcAgent, ::Paused, ::Play, _)
    Hsm.transition!(sm, :Playing)
end

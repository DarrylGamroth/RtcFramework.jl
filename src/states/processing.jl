# Processing state handlers
# Handles common processing state behaviors and transitions

@statedef AbstractRtcAgent :Processing :Ready

@on_initial function (sm::AbstractRtcAgent, ::Processing)
    Hsm.transition!(sm, :Paused)
end

@on_event function (sm::AbstractRtcAgent, ::Processing, ::Stop, _)
    Hsm.transition!(sm, :Stopped)
end

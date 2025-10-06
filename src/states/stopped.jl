# Stopped state handlers
# Handles transitions from stopped to playing state

@statedef AbstractRtcAgent :Stopped :Ready

@on_event function (sm::AbstractRtcAgent, ::Stopped, ::Play, _)
    # # Only transition if all properties are set
    # if allkeysset(sm.properties)
    #     return Hsm.transition!(sm, :Playing)
    # else
    #     throw(ErrorException("Cannot transition to Playing: not all properties are set"))
    # end

    # return Hsm.EventHandled
    Hsm.transition!(sm, :Playing)
end

@on_event function (sm::AbstractRtcAgent, ::Stopped, ::Pause, _)
    Hsm.transition!(sm, :Paused)
end

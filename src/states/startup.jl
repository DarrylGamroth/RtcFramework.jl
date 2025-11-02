# Startup state handlers

@statedef AbstractRtcAgent :Startup

@on_event function (sm::AbstractRtcAgent, ::Startup, ::AgentStarted, _)
    Hsm.transition!(sm, :Top)
end

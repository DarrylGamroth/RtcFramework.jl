# Exit state handlers

@statedef AbstractRtcAgent :Exit

@on_entry function (sm::AbstractRtcAgent, ::Exit)
    throw(AgentTerminationException())
end

@on_exit function (sm::AbstractRtcAgent, ::Exit)
end

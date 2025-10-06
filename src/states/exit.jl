# Exit state handlers
# Handles graceful shutdown and termination

@statedef AbstractRtcAgent :Exit :Top

@on_entry function (sm::AbstractRtcAgent, state::Exit)
    @info "Entering state: $(state)"
    throw(AgentTerminationException())
end

# Error state handlers
# Handles error state entry and behaviors

@statedef AbstractRtcAgent :Error :Top

@on_entry function (sm::AbstractRtcAgent, ::Error)
    @info "Error"
end

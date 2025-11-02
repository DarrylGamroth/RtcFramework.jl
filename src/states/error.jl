# Error state handlers

@statedef AbstractRtcAgent :Error :Top

@on_entry function (sm::AbstractRtcAgent, ::Error)
end

@on_exit function (sm::AbstractRtcAgent, ::Error)
end

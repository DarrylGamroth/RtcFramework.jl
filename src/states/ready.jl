# Ready state handlers
# Handles communication setup/teardown and initial transitions

@statedef AbstractRtcAgent :Ready :Top

@on_initial function (sm::AbstractRtcAgent, ::Ready)
    Hsm.transition!(sm, :Stopped)
end

@on_event function (sm::AbstractRtcAgent, ::Ready, ::Reset, _)
    Hsm.transition!(sm, :Ready)
end

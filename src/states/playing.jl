# Playing state handlers
# Handles events specific to the playing state

@statedef AbstractRtcAgent :Playing :Processing

@on_entry function (sm::AbstractRtcAgent, ::Playing)
    register_poller!(property_poller, sm, :properties, PRIORITY_PROPERTY)
end

@on_exit function (sm::AbstractRtcAgent, ::Playing)
    unregister_poller!(sm, :properties)
end

@on_event function (sm::AbstractRtcAgent, ::Playing, ::Pause, _)
    Hsm.transition!(sm, :Paused)
end

@on_event function (agent::AbstractRtcAgent, ::Playing, ::PublishProperty, config::PublicationConfig)
    publish_property(agent, config)
    return Hsm.EventHandled
end

"""
Event dispatching utilities for agent state machine.

Provides the central dispatch function for routing events through the
hierarchical state machine with automatic state change notification.
"""

"""
    dispatch!(agent::AbstractRtcAgent, event::Symbol, message=nothing)

Dispatch an event through the state machine and publish state changes.

Automatically publishes state change events when transitions occur.
Error events are caught and redirected to the Error state unless they
are AgentTerminationException (which are re-thrown).

# Arguments
- `agent::AbstractRtcAgent`: the agent whose state machine will process the event
- `event::Symbol`: the event to dispatch
- `message`: optional event payload (default: nothing)

# Throws
- `Agent.AgentTerminationException`: when agent termination is requested
"""
function dispatch!(agent::AbstractRtcAgent, event::Symbol, message=nothing)
    try
        prev = Hsm.current(agent)
        Hsm.dispatch!(agent, event, message)
        current = Hsm.current(agent)

        if prev != current
            publish_state_change(agent, current)
        end

    catch e
        if e isa Agent.AgentTerminationException
            throw(e)
        else
            Hsm.dispatch!(agent, :Error, (event, e::Exception))
        end
    end
end

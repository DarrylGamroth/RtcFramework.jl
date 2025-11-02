"""
Test suite for RtcAgent core functionality.
Tests agent construction, lifecycle, and integration with Agent.jl framework.
"""
function test_rtcagent(client)
    @testset "RtcAgent Construction" begin
        # Test basic construction with dependency injection
        clock = CachedEpochClock(EpochClock())
        properties = TestAgent.Properties(clock)
        comms = CommunicationResources(client, properties)
        base_agent = BaseRtcAgent(comms, properties, clock)
        agent = TestAgent.RtcAgent(base_agent)

        @test agent isa TestAgent.RtcAgent
        @test base(agent).source_correlation_id == 0
        @test base(agent).comms === comms
        @test !isnothing(base(agent).clock)
        @test !isnothing(base(agent).properties)
        @test !isnothing(base(agent).id_gen)
        @test !isnothing(base(agent).timers)
        @test isempty(base(agent).property_registry)
        @test base(agent).control_adapter === nothing  # Not yet initialized
        @test isempty(base(agent).input_adapters)      # Not yet initialized
        @test base(agent).status_proxy === nothing     # Not yet initialized
        @test base(agent).property_proxy === nothing   # Not yet initialized

        # Test construction with specific clock
        @testset "Agent should handle specific clock" begin
            clock2 = CachedEpochClock(EpochClock())
            properties2 = TestAgent.Properties(clock2)
            comms2 = CommunicationResources(client, properties2)
            base_agent2 = BaseRtcAgent(comms2, properties2, clock2)
            agent2 = TestAgent.RtcAgent(base_agent2)
            @test base(agent2).clock === clock2
        end
    end

    @testset "Communication Lifecycle" begin
        clock = CachedEpochClock(EpochClock())
        properties = TestAgent.Properties(clock)
        comms = CommunicationResources(client, properties)
        base_agent = BaseRtcAgent(comms, properties, clock)
        agent = TestAgent.RtcAgent(base_agent)

        # Test initial state - communication resources are already created
        @test !isnothing(base(agent).comms)
        @test base(agent).comms isa CommunicationResources
        @test base(agent).control_adapter === nothing
        @test isempty(base(agent).input_adapters)

        # Test that Agent.on_start creates adapters
        Agent.on_start(agent)
        @test !isnothing(base(agent).control_adapter)
        # NOTE: input_adapters might be empty if no input streams are configured

    # Close via state machine: dispatch :Exit to trigger Top @on_exit cleanup
    @test_throws AgentTerminationException dispatch!(agent, :Exit)
        @test base(agent).control_adapter === nothing
        @test isempty(base(agent).input_adapters)

        # Close external resources via Agent.on_close
        Agent.on_close(agent)
    end

    @testset "Agent Interface Implementation" begin
        clock = CachedEpochClock(EpochClock())
        properties = TestAgent.Properties(clock)
        comms = CommunicationResources(client, properties)
        base_agent = BaseRtcAgent(comms, properties, clock)
        agent = TestAgent.RtcAgent(base_agent)

        # Test Agent.name
        name = Agent.name(agent)
        @test name isa String
        @test name == base(agent).properties[:Name]

        # Test Agent.on_start - creates adapters
        result = Agent.on_start(agent)
        @test result === nothing
        @test !isnothing(base(agent).control_adapter)

        # Test Agent.do_work
        work_count = Agent.do_work(agent)
        @test work_count isa Int
        @test work_count >= 0

    # Cleanup via HSM first, then Agent
    @test_throws AgentTerminationException dispatch!(agent, :Exit)
        Agent.on_close(agent)
        @test base(agent).control_adapter === nothing
        @test isempty(base(agent).input_adapters)
    end

    @testset "Dispatch System" begin
        clock = CachedEpochClock(EpochClock())
        properties = TestAgent.Properties(clock)
        comms = CommunicationResources(client, properties)
        base_agent = BaseRtcAgent(comms, properties, clock)
        agent = TestAgent.RtcAgent(base_agent)

        # Test dispatch! function exists and handles events
        @test_nowarn dispatch!(agent, :TestEvent)
        @test_nowarn dispatch!(agent, :AnotherEvent, "test message")
    end

    @testset "Property Registry Management" begin
        clock = CachedEpochClock(EpochClock())
        properties = TestAgent.Properties(clock)
        comms = CommunicationResources(client, properties)
        base_agent = BaseRtcAgent(comms, properties, clock)
        agent = TestAgent.RtcAgent(base_agent)

        # Test property registry operations
        @test isempty(base(agent).property_registry)
        @test !isregistered(agent, :TestProperty)

        # Test that we can access registry functions
        @test empty!(agent) == 0  # No registrations to clear
    end

    @testset "Error Handling" begin
        clock = CachedEpochClock(EpochClock())
        properties = TestAgent.Properties(clock)
        comms = CommunicationResources(client, properties)
        base_agent = BaseRtcAgent(comms, properties, clock)
        agent = TestAgent.RtcAgent(base_agent)

        # Test that agent handles work loop and shutdown gracefully
        @test_nowarn Agent.on_start(agent)
        @test_nowarn Agent.do_work(agent)
        @test_throws AgentTerminationException dispatch!(agent, :Exit)
        @test_nowarn Agent.on_close(agent)

        # Test multiple start/exit/close cycles with new agent AND communication instances
        comms2 = CommunicationResources(client, properties)
        agent2 = TestAgent.RtcAgent(BaseRtcAgent(comms2, properties, clock))
        @test_nowarn Agent.on_start(agent2)
        @test_throws AgentTerminationException dispatch!(agent2, :Exit)
        @test_nowarn Agent.on_close(agent2)

        comms3 = CommunicationResources(client, properties)
        agent3 = TestAgent.RtcAgent(BaseRtcAgent(comms3, properties, clock))
        @test_nowarn Agent.on_start(agent3)
        @test_throws AgentTerminationException dispatch!(agent3, :Exit)
        @test_nowarn Agent.on_close(agent3)
    end

    @testset "Work Loop Components" begin
        clock = CachedEpochClock(EpochClock())
        properties = TestAgent.Properties(clock)
        comms = CommunicationResources(client, properties)
        base_agent = BaseRtcAgent(comms, properties, clock)
        agent = TestAgent.RtcAgent(base_agent)

        Agent.on_start(agent)

        # Test individual work components - these are internal functions
        @test RtcFramework.control_poller(agent) isa Int
        @test RtcFramework.input_poller(agent) isa Int
        @test RtcFramework.timer_poller(agent) isa Int
        @test RtcFramework.property_poller(agent) isa Int

        # All should return 0 in test environment (no actual work)
        @test RtcFramework.control_poller(agent) == 0
        @test RtcFramework.input_poller(agent) == 0
        @test RtcFramework.timer_poller(agent) >= 0  # May have timer work
        @test RtcFramework.property_poller(agent) >= 0  # May publish properties

    # Cleanup via HSM then Agent
    @test_throws AgentTerminationException dispatch!(agent, :Exit)
        Agent.on_close(agent)
    end
end

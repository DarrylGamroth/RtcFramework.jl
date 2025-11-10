# Test suite for state machine transitions and state handlers
function test_states(client)
    @testset "State Transitions" begin
        clock = CachedEpochClock(EpochClock())
        properties = TestAgent.Properties(clock)
        comms = CommunicationResources(client, properties)
        base_agent = BaseRtcAgent(comms, properties, clock)
        agent = TestAgent.RtcAgent(base_agent)
        
        # Start the agent - should transition through states
        Agent.on_start(agent)
        
        # Process work to allow state transitions
        Agent.do_work(agent)
        
        # Test state transitions using dispatch!
        @test_nowarn dispatch!(agent, :Pause)
        @test_nowarn dispatch!(agent, :Play)
        @test_nowarn dispatch!(agent, :Stop)
        
        Agent.on_close(agent)
    end
    
    @testset "Error State Transition" begin
        clock = CachedEpochClock(EpochClock())
        properties = TestAgent.Properties(clock)
        comms = CommunicationResources(client, properties)
        base_agent = BaseRtcAgent(comms, properties, clock)
        agent = TestAgent.RtcAgent(base_agent)
        
        Agent.on_start(agent)
        
        # Trigger error state by dispatching Error event
        @test_nowarn dispatch!(agent, :Error, (:test_error, ErrorException("Test error")))
        
        Agent.on_close(agent)
    end
    
    @testset "Startup State Transitions" begin
        clock = CachedEpochClock(EpochClock())
        properties = TestAgent.Properties(clock)
        comms = CommunicationResources(client, properties)
        base_agent = BaseRtcAgent(comms, properties, clock)
        agent = TestAgent.RtcAgent(base_agent)
        
        # Agent should start in an appropriate initial state
        Agent.on_start(agent)
        @test agent.base !== nothing
        
        # Test that the agent can process work in startup phase
        @test Agent.do_work(agent) >= 0
        
        Agent.on_close(agent)
    end
    
    @testset "Ready State Handling" begin
        clock = CachedEpochClock(EpochClock())
        properties = TestAgent.Properties(clock)
        comms = CommunicationResources(client, properties)
        base_agent = BaseRtcAgent(comms, properties, clock)
        agent = TestAgent.RtcAgent(base_agent)
        
        Agent.on_start(agent)
        
        # Process work multiple times to ensure we transition through states
        for _ in 1:5
            Agent.do_work(agent)
        end
        
        Agent.on_close(agent)
    end
    
    @testset "Processing State" begin
        clock = CachedEpochClock(EpochClock())
        properties = TestAgent.Properties(clock)
        comms = CommunicationResources(client, properties)
        base_agent = BaseRtcAgent(comms, properties, clock)
        agent = TestAgent.RtcAgent(base_agent)
        
        Agent.on_start(agent)
        
        # After startup, should be in Processing state hierarchy
        # Test that work can be done
        work_count = Agent.do_work(agent)
        @test work_count >= 0
        
        Agent.on_close(agent)
    end
end

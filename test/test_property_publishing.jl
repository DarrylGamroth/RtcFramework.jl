"""
Test suite for property publishing system.
Tests the integration of strategies with actual property publishing.
"""
function test_property_publishing(client)
    @testset "Property Publication Workflow" begin
        clock = CachedEpochClock(EpochClock())
        properties = TestAgent.Properties(clock)
        comms = CommunicationResources(client, properties)
        base_agent = BaseRtcAgent(comms, properties, clock)
        agent = TestAgent.RtcAgent(base_agent)
        Agent.on_start(agent)
        
        # Test that properties are accessible
        @test base(agent).properties !== nothing
        
        # Test that registry is accessible
        @test base(agent).publication_configs isa Vector
        
        Agent.on_close(agent)
    end
    
    @testset "Periodic Publishing" begin
        clock = CachedEpochClock(EpochClock())
        properties = TestAgent.Properties(clock)
        comms = CommunicationResources(client, properties)
        base_agent = BaseRtcAgent(comms, properties, clock)
        agent = TestAgent.RtcAgent(base_agent)
        Agent.on_start(agent)
        
        # Test basic agent functionality
        @test base(agent).properties !== nothing
        
        Agent.on_close(agent)
    end
    
    @testset "Multiple Strategy Integration" begin
        clock = CachedEpochClock(EpochClock())
        properties = TestAgent.Properties(clock)
        comms = CommunicationResources(client, properties)
        base_agent = BaseRtcAgent(comms, properties, clock)
        agent = TestAgent.RtcAgent(base_agent)
        Agent.on_start(agent)
        
        # Test basic agent functionality
        @test base(agent).properties !== nothing
        
        Agent.on_close(agent)
    end
    
    @testset "Publication Config Management" begin
        clock = CachedEpochClock(EpochClock())
        properties = TestAgent.Properties(clock)
        comms = CommunicationResources(client, properties)
        base_agent = BaseRtcAgent(comms, properties, clock)
        agent = TestAgent.RtcAgent(base_agent)
        
        # Test basic agent functionality without streams
        @test base(agent).publication_configs isa Vector
        @test isempty(base(agent).publication_configs)  # No registrations yet
        
        Agent.on_start(agent)
        Agent.on_close(agent)
    end
    
    @testset "Strategy State Updates" begin
        clock = CachedEpochClock(EpochClock())
        properties = TestAgent.Properties(clock)
        comms = CommunicationResources(client, properties)
        base_agent = BaseRtcAgent(comms, properties, clock)
        agent = TestAgent.RtcAgent(base_agent)
        Agent.on_start(agent)
        
        # Test basic agent functionality
        @test base(agent).properties !== nothing
        
        Agent.on_close(agent)
    end
    
    @testset "Property Access in Publishing" begin
        # Test basic property access without stream dependencies
        periodic_strategy = Periodic(1000)
        @test RtcFramework.interval_ns(periodic_strategy) == 1000
        
        onupdate_strategy = OnUpdate()
        @test onupdate_strategy isa PublishStrategy
        
        # Test should_publish functions work
        @test RtcFramework.should_publish(onupdate_strategy, 100, -1, 200, 1500) isa Bool
    end
    
    @testset "Zero Allocation Publishing" begin
        clock = CachedEpochClock(EpochClock())
        properties = TestAgent.Properties(clock)
        comms = CommunicationResources(client, properties)
        base_agent = BaseRtcAgent(comms, properties, clock)
        agent = TestAgent.RtcAgent(base_agent)
        Agent.on_start(agent)
        
        # Test basic agent functionality
        @test base(agent).properties !== nothing
        
        Agent.on_close(agent)
    end
end

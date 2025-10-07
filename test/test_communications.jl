"""
Test suite for communication layer functionality.
Tests basic communication setup without requiring actual Aeron streams.
"""
function test_communications(client)
    @testset "Message Publishing" begin
        clock = CachedEpochClock(EpochClock())
        properties = TestAgent.Properties(clock)
        comms = CommunicationResources(client, properties)
        base_agent = BaseRtcAgent(comms, properties, clock)
        agent = TestAgent.RtcAgent(base_agent)
        Agent.on_start(agent)  # Initialize adapters
        
        # Test that basic agent setup works
        @test !isnothing(base(agent).properties)
        @test base(agent).properties[:Name] isa String
        
        # Test that we can access agent properties
        @test haskey(base(agent).properties, :Name)
        @test haskey(base(agent).properties, :NodeId) 
        @test haskey(base(agent).properties, :HeartbeatPeriodNs)
        
        Agent.on_close(agent)
    end
    
    @testset "Communication Setup" begin
        clock = CachedEpochClock(EpochClock())
        properties = TestAgent.Properties(clock)

        # Test communication resources creation
        comms = CommunicationResources(client, properties)
        @test !isnothing(comms)
        @test comms isa CommunicationResources
        @test !isnothing(comms.status_stream)
        @test !isnothing(comms.control_stream)
        @test comms.input_streams isa Vector
        @test comms.output_streams isa Vector
        
        # Test agent construction with dependency injection
        base_agent = BaseRtcAgent(comms, properties, clock)
        agent = TestAgent.RtcAgent(base_agent)
        @test !isnothing(agent)
        @test !isnothing(base(agent).properties)
        @test base(agent).comms === comms
        
        # Test agent lifecycle
        @test_nowarn Agent.on_start(agent)
        @test_nowarn Agent.on_close(agent)
    end
end

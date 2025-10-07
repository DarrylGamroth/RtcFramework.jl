using Aeron
using Clocks

"""
Test suite for stream adapter functionality.
Tests ControlStreamAdapter and InputStreamAdapter operations.
"""
function test_adapters(client)
    @testset "ControlStreamAdapter" begin
        clock = CachedEpochClock(EpochClock())
        properties = TestAgent.Properties(clock)
        comms = CommunicationResources(client, properties)
        base_agent = BaseRtcAgent(comms, properties, clock)
        agent = TestAgent.RtcAgent(base_agent)
        
        # Test adapter creation
        adapter = RtcFramework.ControlStreamAdapter(comms.control_stream, agent)
        @test adapter isa RtcFramework.ControlStreamAdapter
        @test !isnothing(adapter.subscription)
        @test !isnothing(adapter.assembler)
        
        # Test polling (should return 0 in empty test environment)
        fragments_read = RtcFramework.poll(adapter, 10)
        @test fragments_read isa Int
        @test fragments_read == 0
    end
    
    @testset "InputStreamAdapter" begin
        clock = CachedEpochClock(EpochClock())
        properties = TestAgent.Properties(clock)
        comms = CommunicationResources(client, properties)
        base_agent = BaseRtcAgent(comms, properties, clock)
        agent = TestAgent.RtcAgent(base_agent)
        
        # Test single adapter creation and operation
        if !isempty(comms.input_streams)
            adapter = RtcFramework.InputStreamAdapter(comms.input_streams[1], agent)
            @test adapter isa RtcFramework.InputStreamAdapter
            @test !isnothing(adapter.subscription)
            @test !isnothing(adapter.assembler)
            
            # Test polling (should return 0 in empty test environment)
            fragments_read = RtcFramework.poll(adapter, 10)
            @test fragments_read isa Int
            @test fragments_read == 0
        end
        
        # Test multiple adapter creation and polling
        adapters = RtcFramework.InputStreamAdapter[]
        for stream in comms.input_streams
            push!(adapters, RtcFramework.InputStreamAdapter(stream, agent))
        end
        
        # Test vector polling
        total_fragments = RtcFramework.poll(adapters, 10)
        @test total_fragments isa Int
        @test total_fragments == 0
        
        # Test empty adapter vector
        empty_adapters = RtcFramework.InputStreamAdapter[]
        @test RtcFramework.poll(empty_adapters, 10) == 0
    end
    
    @testset "CommunicationResources" begin
        clock = CachedEpochClock(EpochClock())
        properties = TestAgent.Properties(clock)
        
        # Test construction
        comms = CommunicationResources(client, properties)
        @test comms isa CommunicationResources
        @test !isnothing(comms.status_stream)
        @test !isnothing(comms.control_stream)
        @test comms.input_streams isa Vector{Aeron.Subscription}
        @test comms.output_streams isa Vector{Aeron.ExclusivePublication}
        
        # Test that streams are created according to properties
        @test comms.status_stream isa Aeron.ExclusivePublication
        @test comms.control_stream isa Aeron.Subscription
        
        # Test that streams are properly initialized (not closed)
        @test isopen(comms.status_stream)
        @test isopen(comms.control_stream)
        
        # Test close functionality
        @test_nowarn close(comms)
    end
    
    @testset "Agent Adapter Integration" begin
        clock = CachedEpochClock(EpochClock())
        properties = TestAgent.Properties(clock)
        comms = CommunicationResources(client, properties)
        base_agent = BaseRtcAgent(comms, properties, clock)
        agent = TestAgent.RtcAgent(base_agent)
        
        # Test initial state
        @test base(agent).control_adapter === nothing
        @test isempty(base(agent).input_adapters)
        
        # Test adapter creation via Agent.on_start
        Agent.on_start(agent)
        @test !isnothing(base(agent).control_adapter)
        @test base(agent).control_adapter isa RtcFramework.ControlStreamAdapter
        @test length(base(agent).input_adapters) == length(comms.input_streams)
        @test all(adapter -> adapter isa RtcFramework.InputStreamAdapter, base(agent).input_adapters)
        
        # Test adapter polling via agent pollers
        @test RtcFramework.control_poller(agent) == 0
        @test RtcFramework.input_poller(agent) == 0
        
        # Test adapter cleanup via Agent.on_close
        Agent.on_close(agent)
        @test base(agent).control_adapter === nothing
        @test isempty(base(agent).input_adapters)
    end
end

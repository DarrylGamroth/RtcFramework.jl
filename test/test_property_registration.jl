# Test suite for property registration system
function test_property_registration(client)
    @testset "register_property!" begin
        clock = CachedEpochClock(EpochClock())
        properties = TestAgent.Properties(clock)
        comms = CommunicationResources(client, properties)
        base_agent = BaseRtcAgent(comms, properties, clock)
        agent = TestAgent.RtcAgent(base_agent)
        
        # Only test if output streams exist
        if !isempty(base(agent).comms.output_streams)
            # Test registering a property
            strategy = OnUpdate()
            register_property!(agent, :TestValue, 1, strategy)
            @test isregistered_property(agent, :TestValue)
            @test isregistered_property(agent, :TestValue, 1)
            @test !isregistered_property(agent, :TestValue, 2)
            @test length(base(agent).publication_configs) == 1
        else
            @warn "No output streams configured, skipping register_property! test"
        end
        
        Agent.on_close(agent)
    end
    
    @testset "register_property! with invalid stream" begin
        clock = CachedEpochClock(EpochClock())
        properties = TestAgent.Properties(clock)
        comms = CommunicationResources(client, properties)
        base_agent = BaseRtcAgent(comms, properties, clock)
        agent = TestAgent.RtcAgent(base_agent)
        
        # Test invalid stream index
        strategy = OnUpdate()
        num_streams = length(base(agent).comms.output_streams)
        @test_throws RtcFramework.StreamNotFoundError register_property!(agent, :TestValue, num_streams + 1, strategy)
        @test_throws RtcFramework.StreamNotFoundError register_property!(agent, :TestValue, 0, strategy)
        
        Agent.on_close(agent)
    end
    
    @testset "unregister_property! by field and stream" begin
        clock = CachedEpochClock(EpochClock())
        properties = TestAgent.Properties(clock)
        comms = CommunicationResources(client, properties)
        base_agent = BaseRtcAgent(comms, properties, clock)
        agent = TestAgent.RtcAgent(base_agent)
        
        # Only test if output streams exist
        if !isempty(base(agent).comms.output_streams)
            # Register and then unregister
            strategy = OnUpdate()
            register_property!(agent, :TestValue, 1, strategy)
            @test isregistered_property(agent, :TestValue, 1)
            
            removed = unregister_property!(agent, :TestValue, 1)
            @test removed == 1
            @test !isregistered_property(agent, :TestValue, 1)
            
            # Try to unregister again - should return 0
            removed = unregister_property!(agent, :TestValue, 1)
            @test removed == 0
        else
            @warn "No output streams configured, skipping unregister test"
        end
        
        Agent.on_close(agent)
    end
    
    @testset "unregister_property! by field only" begin
        clock = CachedEpochClock(EpochClock())
        properties = TestAgent.Properties(clock)
        comms = CommunicationResources(client, properties)
        base_agent = BaseRtcAgent(comms, properties, clock)
        agent = TestAgent.RtcAgent(base_agent)
        
        # Only test if output streams exist
        if !isempty(base(agent).comms.output_streams)
            # Register same property on multiple streams
            strategy = OnUpdate()
            if length(base(agent).comms.output_streams) >= 2
                register_property!(agent, :TestValue, 1, strategy)
                register_property!(agent, :TestValue, 2, strategy)
                @test isregistered_property(agent, :TestValue, 1)
                @test isregistered_property(agent, :TestValue, 2)
                
                # Unregister all occurrences of the field
                removed = unregister_property!(agent, :TestValue)
                @test removed == 2
                @test !isregistered_property(agent, :TestValue)
            else
                # If only one stream, test single registration
                register_property!(agent, :TestValue, 1, strategy)
                removed = unregister_property!(agent, :TestValue)
                @test removed == 1
                @test !isregistered_property(agent, :TestValue)
            end
            
            # Try to unregister again - should return 0
            removed = unregister_property!(agent, :TestValue)
            @test removed == 0
        else
            @warn "No output streams configured, skipping unregister test"
        end
        
        Agent.on_close(agent)
    end
    
    @testset "isregistered_property queries" begin
        clock = CachedEpochClock(EpochClock())
        properties = TestAgent.Properties(clock)
        comms = CommunicationResources(client, properties)
        base_agent = BaseRtcAgent(comms, properties, clock)
        agent = TestAgent.RtcAgent(base_agent)
        
        # Initially not registered
        @test !isregistered_property(agent, :TestValue)
        @test !isregistered_property(agent, :TestValue, 1)
        
        # Only test further if output streams exist
        if !isempty(base(agent).comms.output_streams)
            # Register on stream 1
            strategy = OnUpdate()
            register_property!(agent, :TestValue, 1, strategy)
            
            # Should be registered on stream 1 but not on stream 2
            @test isregistered_property(agent, :TestValue)
            @test isregistered_property(agent, :TestValue, 1)
            if length(base(agent).comms.output_streams) >= 2
                @test !isregistered_property(agent, :TestValue, 2)
            end
        end
        
        Agent.on_close(agent)
    end
    
    @testset "Multiple registrations with different strategies" begin
        clock = CachedEpochClock(EpochClock())
        properties = TestAgent.Properties(clock)
        comms = CommunicationResources(client, properties)
        base_agent = BaseRtcAgent(comms, properties, clock)
        agent = TestAgent.RtcAgent(base_agent)
        
        # Only test if output streams exist
        if !isempty(base(agent).comms.output_streams)
            # Register same property with different strategies
            onupdate_strategy = OnUpdate()
            periodic_strategy = Periodic(1000000)
            
            register_property!(agent, :TestValue, 1, onupdate_strategy)
            register_property!(agent, :TestString, 1, periodic_strategy)
            
            @test isregistered_property(agent, :TestValue)
            @test isregistered_property(agent, :TestString)
            @test length(base(agent).publication_configs) == 2
        else
            @warn "No output streams configured, skipping multiple registration test"
        end
        
        Agent.on_close(agent)
    end
end

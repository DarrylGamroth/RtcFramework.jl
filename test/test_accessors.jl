"""
Test suite for convenience accessor functions.
Tests properties() and timers() accessors for AbstractRtcAgent.
"""
function test_accessors(client)
    @testset "Convenience Accessors" begin
        # Setup
        clock = CachedEpochClock(EpochClock())
        props = TestAgent.Properties(clock)
        comms = CommunicationResources(client, props)
        base_agent = BaseRtcAgent(comms, props, clock)
        agent = TestAgent.RtcAgent(base_agent)

        @testset "properties accessor" begin
            # Test that properties(agent) returns the property store
            prop_store = properties(agent)
            @test prop_store === base(agent).properties
            @test prop_store isa RtcFramework.AbstractStaticKV
            
            # Test that we can use it like the property store
            @test haskey(prop_store, :Name)
            @test prop_store[:Name] == "TestAgent"
            
            # Test that we can read existing fields
            @test prop_store[:NodeId] == 1
            @test properties(agent)[:NodeId] == base(agent).properties[:NodeId]
        end

        @testset "timers accessor" begin
            # Test that timers(agent) returns the timer system
            timer_system = timers(agent)
            @test timer_system === base(agent).timers
            @test timer_system isa RtcFramework.PolledTimer
            
            # Test that we can use it for timer operations
            schedule!(timers(agent), 1_000_000_000, :TestTimer)
            @test true  # If we got here, schedule! worked
            
            # Cancel the timer
            cancel!(timers(agent), :TestTimer)
            @test true  # If we got here, cancel! worked
        end

        @testset "accessor type stability" begin
            # Verify type stability of accessors
            @test (@inferred properties(agent)) === base(agent).properties
            @test (@inferred timers(agent)) === base(agent).timers
        end

        # Cleanup
        close(comms)
    end
end

"""
Test suite for convenience accessor functions.
Tests properties() and timers() accessors for AbstractRtcAgent.
"""
function test_accessors(client)
    @testset "Convenience Accessors" begin
        # Setup
        clock = CachedEpochClock(EpochClock())
        props = TestAgent.Properties(clock)
        comm_resources = CommunicationResources(client, props)
        base_agent = BaseRtcAgent(comm_resources, props, clock)
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

        @testset "comms accessor" begin
            # Test that comms(agent) returns the communication resources
            comm_resources_result = comms(agent)
            @test comm_resources_result === base(agent).comms
            @test comm_resources_result isa RtcFramework.CommunicationResources

            # Test that we can access fields
            @test comms(agent).client === client
        end

        @testset "accessor type stability" begin
            # Verify type stability of accessors
            @test (@inferred properties(agent)) === base(agent).properties
            @test (@inferred timers(agent)) === base(agent).timers
            @test (@inferred comms(agent)) === base(agent).comms
        end

        # Cleanup
        close(comm_resources)
    end
end

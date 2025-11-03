"""
Test suite for counter system.
Tests counter allocation, operations, and agent identification.
"""
function test_counters(client)
    @testset "Counters struct fields" begin
        agent_id = Int64(42)
        agent_name = "TestAgent"

        counters = Counters(client, agent_id, agent_name)
        
        # Test all counter fields are allocated
        @test !isnothing(counters.duty_cycles)
        @test !isnothing(counters.work_done)
        @test !isnothing(counters.properties_published)
        
        # Test counters are Aeron.Counter instances
        @test counters.duty_cycles isa Aeron.Counter
        @test counters.work_done isa Aeron.Counter
        @test counters.properties_published isa Aeron.Counter
        
        # Test initial values are zero
        @test counters.duty_cycles[] == 0
        @test counters.work_done[] == 0
        @test counters.properties_published[] == 0
    end

    @testset "Counter operations" begin
        counters = Counters(client, Int64(1), "TestOps")

        # Test increment by 1 (default)
        Aeron.increment!(counters.duty_cycles)
        @test counters.duty_cycles[] == 1

        Aeron.increment!(counters.duty_cycles)
        @test counters.duty_cycles[] == 2

        # Test increment by delta
        Aeron.increment!(counters.work_done, 10)
        @test counters.work_done[] == 10

        Aeron.increment!(counters.work_done, 5)
        @test counters.work_done[] == 15

        # Test set operation
        counters.properties_published[] = 100
        @test counters.properties_published[] == 100

        # Test counters are independent
        @test counters.duty_cycles[] == 2
        @test counters.work_done[] == 15
        @test counters.properties_published[] == 100
    end

    @testset "add_counter helper function" begin
        agent_id = Int64(123)
        agent_name = "HelperTest"
        
        # Test add_counter creates a valid counter
        custom_counter = RtcFramework.add_counter(client, agent_id, agent_name, Int32(2001), "CustomCounter")
        @test custom_counter isa Aeron.Counter
        @test custom_counter[] == 0
        
        # Test counter is usable
        Aeron.increment!(custom_counter, 42)
        @test custom_counter[] == 42
        
        close(custom_counter)
    end

    @testset "Multiple agents sharing MediaDriver" begin
        # Simulate multiple agents
        agent1 = Counters(client, Int64(1), "Agent1")
        agent2 = Counters(client, Int64(2), "Agent2")
        agent3 = Counters(client, Int64(3), "Agent3")

        # Each agent's counters are independent
        Aeron.increment!(agent1.duty_cycles, 10)
        Aeron.increment!(agent2.duty_cycles, 20)
        Aeron.increment!(agent3.duty_cycles, 30)

        @test agent1.duty_cycles[] == 10
        @test agent2.duty_cycles[] == 20
        @test agent3.duty_cycles[] == 30
    end

    @testset "Counter close" begin
        counters = Counters(client, Int64(100), "TestClose")

        # Verify counters are open
        @test Aeron.isopen(counters.duty_cycles)
        @test Aeron.isopen(counters.work_done)
        @test Aeron.isopen(counters.properties_published)

        # Close all counters
        close(counters)

        # Verify all counters are closed
        @test !Aeron.isopen(counters.duty_cycles)
        @test !Aeron.isopen(counters.work_done)
        @test !Aeron.isopen(counters.properties_published)
    end
end

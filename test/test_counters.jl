"""
Test suite for counter system.
Tests counter allocation, operations, and agent identification.
"""
function test_counters(client)
    @testset "CounterId enum" begin
        # Test enum values match expected indices (1-based)
        @test Int(TOTAL_DUTY_CYCLES) == 1
        @test Int(TOTAL_WORK_DONE) == 2
        @test Int(PROPERTIES_PUBLISHED) == 3

        # Test enumeration
        all_ids = collect(instances(CounterId))
        @test length(all_ids) == 3
        @test TOTAL_DUTY_CYCLES in all_ids
        @test TOTAL_WORK_DONE in all_ids
        @test PROPERTIES_PUBLISHED in all_ids
    end

    @testset "COUNTER_METADATA" begin
        # Test metadata array structure
        @test length(RtcFramework.COUNTER_METADATA) == 3

        # Test type IDs are correctly calculated (BASE + enum value)
        for metadata in RtcFramework.COUNTER_METADATA
            expected_type_id = RtcFramework.BASE_COUNTER_TYPE_ID + Int32(metadata.id)
            @test metadata.type_id == expected_type_id
        end

        # Test specific metadata entries
        total_cycles_meta = RtcFramework.COUNTER_METADATA[1]
        @test total_cycles_meta.id == TOTAL_DUTY_CYCLES
        @test total_cycles_meta.type_id == 1001
        @test total_cycles_meta.label == "TotalDutyCycles"
        @test !isempty(total_cycles_meta.description)

        total_work_meta = RtcFramework.COUNTER_METADATA[2]
        @test total_work_meta.id == TOTAL_WORK_DONE
        @test total_work_meta.type_id == 1002
        @test total_work_meta.label == "TotalWorkDone"

        props_published_meta = RtcFramework.COUNTER_METADATA[3]
        @test props_published_meta.id == PROPERTIES_PUBLISHED
        @test props_published_meta.type_id == 1003
        @test props_published_meta.label == "PropertiesPublished"
    end

    @testset "Counters allocation and access" begin
        agent_id = Int64(42)
        agent_name = "TestAgent"

        # Test Counters construction
        counters = Counters(client, agent_id, agent_name)
        @test counters.agent_id == agent_id
        @test counters.agent_name == agent_name
        @test length(counters.vec) == 3

        # Test all counters are allocated
        @test !isnothing(counters.vec[Int(TOTAL_DUTY_CYCLES)])
        @test !isnothing(counters.vec[Int(TOTAL_WORK_DONE)])
        @test !isnothing(counters.vec[Int(PROPERTIES_PUBLISHED)])

        # Test initial values are zero
        @test get_counter(counters, TOTAL_DUTY_CYCLES) == 0
        @test get_counter(counters, TOTAL_WORK_DONE) == 0
        @test get_counter(counters, PROPERTIES_PUBLISHED) == 0
    end

    @testset "Counter operations" begin
        counters = Counters(client, Int64(1), "TestOps")

        # Test increment by 1 (default)
        increment_counter!(counters, TOTAL_DUTY_CYCLES)
        @test get_counter(counters, TOTAL_DUTY_CYCLES) == 1

        increment_counter!(counters, TOTAL_DUTY_CYCLES)
        @test get_counter(counters, TOTAL_DUTY_CYCLES) == 2

        # Test increment by delta
        increment_counter!(counters, TOTAL_WORK_DONE, 10)
        @test get_counter(counters, TOTAL_WORK_DONE) == 10

        increment_counter!(counters, TOTAL_WORK_DONE, 5)
        @test get_counter(counters, TOTAL_WORK_DONE) == 15

        # Test set operation
        counter = counters.vec[Int(PROPERTIES_PUBLISHED)]
        set_counter!(counter, 100)
        @test get_counter(counters, PROPERTIES_PUBLISHED) == 100

        # Test counters are independent
        @test get_counter(counters, TOTAL_DUTY_CYCLES) == 2
        @test get_counter(counters, TOTAL_WORK_DONE) == 15
        @test get_counter(counters, PROPERTIES_PUBLISHED) == 100
    end

    @testset "Counter key buffer format" begin
        agent_id = Int64(0x123456789ABCDEF0)  # Specific bit pattern
        agent_name = "TestKeyBuffer"

        counters = Counters(client, agent_id, agent_name)

        # Verify counters are allocated with agent metadata
        @test counters.agent_id == agent_id
        @test counters.agent_name == agent_name
        @test length(counters.vec) == 3

        # Verify different agents have different identification
        counters2 = Counters(client, Int64(999), "DifferentAgent")
        @test counters2.agent_id != counters.agent_id
        @test counters2.agent_name != counters.agent_name
    end

    @testset "Multiple agents sharing MediaDriver" begin
        # Simulate multiple agents
        agent1 = Counters(client, Int64(1), "Agent1")
        agent2 = Counters(client, Int64(2), "Agent2")
        agent3 = Counters(client, Int64(3), "Agent3")

        # Each agent's counters are independent
        increment_counter!(agent1, TOTAL_DUTY_CYCLES, 10)
        increment_counter!(agent2, TOTAL_DUTY_CYCLES, 20)
        increment_counter!(agent3, TOTAL_DUTY_CYCLES, 30)

        @test get_counter(agent1, TOTAL_DUTY_CYCLES) == 10
        @test get_counter(agent2, TOTAL_DUTY_CYCLES) == 20
        @test get_counter(agent3, TOTAL_DUTY_CYCLES) == 30
    end

    @testset "Counter close" begin
        counters = Counters(client, Int64(100), "TestClose")

        # Verify counters are open
        for counter in counters.vec
            @test Aeron.isopen(counter)
        end

        # Close all counters
        close(counters)

        # Verify all counters are closed
        for counter in counters.vec
            @test !Aeron.isopen(counter)
        end
    end
end

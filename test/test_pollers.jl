"""
Test suite for unified poller system.
Tests poller registration, priority ordering, execution, and type stability.
"""
function test_pollers(client)
    @testset "Poller Registration" begin
        clock = CachedEpochClock(EpochClock())
        properties = TestAgent.Properties(clock)
        comms = CommunicationResources(client, properties)
        base_agent = BaseRtcAgent(comms, properties, clock)
        agent = TestAgent.RtcAgent(base_agent)

        # Start agent to register built-in pollers
        Agent.on_start(agent)

        @testset "Built-in pollers registered on start" begin
            loop = pollers(agent)
            @test length(loop) == 4

            # Check that all built-in pollers are registered
            @test :input_streams in loop
            @test :properties in loop
            @test :timers in loop
            @test :control_stream in loop

            # Verify priority order (lower number = higher priority)
            priorities = [p.priority for p in loop]
            @test issorted(priorities)
        end

        @testset "Custom poller registration" begin
            # Define a simple test poller
            test_poller_called = Ref(false)
            function test_poller(agent)
                test_poller_called[] = true
                return 1
            end

            # Register custom poller
            register_poller!(test_poller, agent, 100; name=:test_poller)

            # Apply deferred registration
            Agent.do_work(agent)

            # Verify it was added
            loop = pollers(agent)
            @test length(loop) == 5
            @test :test_poller in loop

            # Verify work is executed
            Agent.do_work(agent)
            @test test_poller_called[]
        end

        @testset "Multiple pollers at same priority (FIFO)" begin
            call_order = Int[]

            function poller_a(agent)
                push!(call_order, 1)
                return 0
            end

            function poller_b(agent)
                push!(call_order, 2)
                return 0
            end

            # Register both at same priority
            register_poller!(poller_a, agent, 150; name=:poller_a)
            register_poller!(poller_b, agent, 150; name=:poller_b)

            # Apply registrations
            Agent.do_work(agent)

            # Clear call order and execute again
            empty!(call_order)
            Agent.do_work(agent)

            # Verify FIFO order (poller_a registered first, should run first)
            @test length(call_order) >= 2
            idx_a = findfirst(==(1), call_order)
            idx_b = findfirst(==(2), call_order)
            @test idx_a < idx_b
        end

        @testset "Do-block syntax" begin
            do_block_called = Ref(false)

            register_poller!(agent, 200; name=:do_block_poller) do agent
                do_block_called[] = true
                return 1
            end

            # Apply deferred registration
            Agent.do_work(agent)

            # Verify it was registered
            @test :do_block_poller in agent

            # Verify it executes
            Agent.do_work(agent)
            @test do_block_called[]
        end

        Agent.on_close(agent)
    end

    @testset "Execution Order" begin
        clock = CachedEpochClock(EpochClock())
        properties = TestAgent.Properties(clock)
        comms = CommunicationResources(client, properties)
        base_agent = BaseRtcAgent(comms, properties, clock)
        agent = TestAgent.RtcAgent(base_agent)

        # Start with built-in pollers
        Agent.on_start(agent)

        @testset "Pollers execute in priority order" begin
            execution_order = Int[]

            # Register pollers with different priorities
            register_poller!(agent, 5; name=:highest) do agent
                push!(execution_order, 5)
                return 0
            end

            register_poller!(agent, 100; name=:medium) do agent
                push!(execution_order, 100)
                return 0
            end

            register_poller!(agent, 20; name=:high) do agent
                push!(execution_order, 20)
                return 0
            end

            register_poller!(agent, 500; name=:lowest) do agent
                push!(execution_order, 500)
                return 0
            end

            # Apply all registrations
            Agent.do_work(agent)

            # Execute all pollers
            empty!(execution_order)
            Agent.do_work(agent)

            # Verify priorities are in ascending order
            # (lower priority number executes first)
            @test issorted(execution_order)
            @test execution_order[1] == 5
            @test execution_order[end] == 500
        end

        @testset "Work count accumulation" begin
            # Register pollers that return specific work counts
            register_poller!(agent, 300; name=:work_5) do agent
                return 5
            end

            register_poller!(agent, 301; name=:work_3) do agent
                return 3
            end

            register_poller!(agent, 302; name=:work_7) do agent
                return 7
            end

            # Apply registrations first
            Agent.do_work(agent)

            # Execute and verify total work count includes custom pollers
            total_work = Agent.do_work(agent)
            @test total_work >= 15  # At least 5 + 3 + 7 from our custom pollers
        end

        Agent.on_close(agent)
    end

    @testset "Poller Management" begin
        clock = CachedEpochClock(EpochClock())
        properties = TestAgent.Properties(clock)
        comms = CommunicationResources(client, properties)
        base_agent = BaseRtcAgent(comms, properties, clock)
        agent = TestAgent.RtcAgent(base_agent)

        Agent.on_start(agent)

        @testset "Unregister poller by name" begin
            # Register a test poller
            register_poller!(agent, 400; name=:to_remove) do agent
                return 1
            end

            # Apply registration
            Agent.do_work(agent)

            initial_count = length(pollers(agent))

            # Unregister it (deferred)
            result = unregister_poller!(agent, :to_remove)
            @test result == true

            # Apply unregistration
            Agent.do_work(agent)
            @test length(pollers(agent)) == initial_count - 1

            # Verify it's gone
            @test !(:to_remove in agent)

            # Try to unregister non-existent poller
            result = unregister_poller!(agent, :nonexistent)
            @test result == false
        end

        @testset "Clear all pollers" begin
            # Register some custom pollers
            register_poller!(agent, 100; name=:custom1) do agent; return 0; end
            register_poller!(agent, 200; name=:custom2) do agent; return 0; end

            # Apply registrations
            Agent.do_work(agent)

            count_before = length(pollers(agent))
            @test count_before > 0

            # Clear all pollers (immediate)
            removed_count = clear_pollers!(agent)
            @test removed_count == count_before
            @test length(pollers(agent)) == 0
        end

        @testset "List pollers" begin
            # Add a couple of test pollers to verify structure
            register_poller!(agent, 100; name=:list_test1) do agent; return 0; end
            register_poller!(agent, 200; name=:list_test2) do agent; return 0; end
            Agent.do_work(agent)

            loop = pollers(agent)

            # Verify structure of returned data
            @test loop isa RtcFramework.PollerLoop
            @test length(loop) >= 2  # At least our 2 test pollers

            # Verify iteration
            for (idx, poller) in enumerate(loop)
                @test poller isa RtcFramework.PollerConfig
                @test poller.name isa Symbol
                @test poller.priority isa Int
            end
        end

        @testset "Reordering pollers" begin
            # Register pollers with specific priorities
            register_poller!(agent, 50; name=:test_a) do agent; return 0; end
            register_poller!(agent, 100; name=:test_b) do agent; return 0; end
            Agent.do_work(agent)

            # Unregister and re-register with different priority
            unregister_poller!(agent, :test_b)
            register_poller!(agent, 25; name=:test_b) do agent; return 0; end

            # Apply changes
            Agent.do_work(agent)

            loop = pollers(agent)
            test_b = findfirst(p -> p.name == :test_b, loop)
            @test loop[test_b].priority == 25

            # Verify still in sorted order
            priorities = [p.priority for p in loop]
            @test issorted(priorities)
        end

        Agent.on_close(agent)
    end

    @testset "Type Stability" begin
        clock = CachedEpochClock(EpochClock())
        properties = TestAgent.Properties(clock)
        comms = CommunicationResources(client, properties)
        base_agent = BaseRtcAgent(comms, properties, clock)
        agent = TestAgent.RtcAgent(base_agent)

        Agent.on_start(agent)

        @testset "do_work is type-stable" begin
            # Register a custom poller
            register_poller!(agent, 100; name=:type_test) do agent
                return 42
            end

            # Apply registration and test that do_work returns Int
            Agent.do_work(agent)  # Apply registration
            result = @inferred Int Agent.do_work(agent)
            @test result isa Int
        end

        @testset "Poller functions are type-stable" begin
            # PollerFunction should wrap functions in type-stable way
            test_fn = agent -> 1
            wrapped = RtcFramework.PollerFunction(test_fn)

            @test wrapped isa RtcFramework.PollerFunction
            result = wrapped(agent)
            @test result isa Int
        end

        Agent.on_close(agent)
    end

    @testset "Built-in Pollers Integration" begin
        clock = CachedEpochClock(EpochClock())
        properties = TestAgent.Properties(clock)
        comms = CommunicationResources(client, properties)
        base_agent = BaseRtcAgent(comms, properties, clock)
        agent = TestAgent.RtcAgent(base_agent)

        @testset "Built-in pollers registered automatically" begin
            # Before on_start, no pollers
            @test isempty(pollers(agent))

            # After on_start, built-in pollers registered
            Agent.on_start(agent)
            loop = pollers(agent)
            @test length(loop) == 4

            # Verify expected priorities
            poller_map = Dict(p.name => p.priority for p in loop)
            @test poller_map[:input_streams] < poller_map[:properties]
            @test poller_map[:properties] < poller_map[:timers]
            @test poller_map[:timers] < poller_map[:control_stream]
        end

        @testset "Built-in pollers cleared on close" begin
            # Close from previous testset, then restart
            Agent.on_close(agent)
            Agent.on_start(agent)
            @test !isempty(pollers(agent))

            Agent.on_close(agent)
            @test isempty(pollers(agent))
        end

        @testset "Custom pollers interleave with built-ins" begin
            # Restart after previous close
            Agent.on_start(agent)

            # Add custom poller between input and property
            register_poller!(agent, 30; name=:between_input_property) do agent
                return 0
            end

            # Apply registration
            Agent.do_work(agent)

            loop = pollers(agent)
            positions = Dict(p.name => idx for (idx, p) in enumerate(loop))

            # Verify ordering
            @test positions[:input_streams] < positions[:between_input_property]
            @test positions[:between_input_property] < positions[:properties]
        end

        Agent.on_close(agent)
    end
end

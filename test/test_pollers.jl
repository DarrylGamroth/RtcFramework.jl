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
            # Apply deferred registrations from on_start
            Agent.do_work(agent)

            registry = pollers(agent)
            @test length(registry) == 4

            # Check that unconditional built-in pollers are registered
            @test :timers in registry
            @test :control_stream in registry

            # Verify priority order (lower number = higher priority)
            priorities = [p.priority for p in registry]
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
            register_poller!(test_poller, agent, :test_poller, 100)

            # Apply all registrations
            Agent.do_work(agent)

            # Verify it was added
            registry = pollers(agent)
            @test length(registry) == 5  # 4 built-in + 1 custom
            @test :test_poller in registry

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
            register_poller!(poller_a, agent, :poller_a, 150)
            register_poller!(poller_b, agent, :poller_b, 150)

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

            register_poller!(agent, :do_block_poller, 200) do agent
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
            register_poller!(agent, :highest, 5) do agent
                push!(execution_order, 5)
                return 0
            end

            register_poller!(agent, :medium, 100) do agent
                push!(execution_order, 100)
                return 0
            end

            register_poller!(agent, :high, 20) do agent
                push!(execution_order, 20)
                return 0
            end

            register_poller!(agent, :lowest, 500) do agent
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
            register_poller!(agent, :work_5, 300) do agent
                return 5
            end

            register_poller!(agent, :work_3, 301) do agent
                return 3
            end

            register_poller!(agent, :work_7, 302) do agent
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
            register_poller!(agent, :to_remove, 400) do agent
                return 1
            end

            # Apply registration
            Agent.do_work(agent)

            initial_count = length(pollers(agent))

            # Unregister it (deferred)
            unregister_poller!(agent, :to_remove)

            # Apply unregistration
            Agent.do_work(agent)
            @test length(pollers(agent)) == initial_count - 1

            # Verify it's gone
            @test !(:to_remove in agent)

            # Unregister non-existent poller (should be idempotent, no error)
            unregister_poller!(agent, :nonexistent)
            # Should still work fine
            @test length(pollers(agent)) == initial_count - 1
        end

        @testset "Clear all pollers" begin
            # Register some custom pollers
            register_poller!(agent, :custom1, 100) do agent; return 0; end
            register_poller!(agent, :custom2, 200) do agent; return 0; end

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
            register_poller!(agent, :list_test1, 100) do agent; return 0; end
            register_poller!(agent, :list_test2, 200) do agent; return 0; end
            Agent.do_work(agent)

            registry = pollers(agent)

            # Verify structure of returned data
            @test registry isa RtcFramework.PollerRegistry
            @test length(registry) >= 2  # At least our 2 test pollers

            # Verify iteration
            for (idx, poller) in enumerate(registry)
                @test poller isa RtcFramework.PollerConfig
                @test poller.name isa Symbol
                @test poller.priority isa Int
            end
        end

        @testset "Reordering pollers" begin
            # Register pollers with specific priorities
            register_poller!(agent, :test_a, 50) do agent; return 0; end
            register_poller!(agent, :test_b, 100) do agent; return 0; end
            Agent.do_work(agent)

            # Unregister and re-register with different priority
            unregister_poller!(agent, :test_b)
            register_poller!(agent, :test_b, 25) do agent; return 0; end

            # Apply changes
            Agent.do_work(agent)

            registry = pollers(agent)
            test_b = findfirst(p -> p.name == :test_b, registry)
            @test registry[test_b].priority == 25

            # Verify still in sorted order
            priorities = [p.priority for p in registry]
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
            register_poller!(agent, :type_test, 100) do agent
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

            # After on_start, built-in pollers registered (but deferred)
            Agent.on_start(agent)

            # Apply deferred registrations
            Agent.do_work(agent)

            registry = pollers(agent)

            @test length(registry) == 4

            # Verify expected priorities for unconditional pollers
            poller_map = Dict(p.name => p.priority for p in registry)
            @test poller_map[:timers] < poller_map[:control_stream]
        end

        @testset "Built-in pollers cleared on close" begin
            # Close from previous testset, then restart
            Agent.on_close(agent)
            Agent.on_start(agent)
            Agent.do_work(agent)  # Apply deferred registrations
            @test !isempty(pollers(agent))

            Agent.on_close(agent)
            @test isempty(pollers(agent))
        end

        @testset "Custom pollers interleave with built-ins" begin
            # Restart after previous close
            Agent.on_start(agent)
            Agent.do_work(agent)  # Apply built-in pollers

            # Add custom poller between timer and control
            register_poller!(agent, :between_timer_control, 100) do agent
                return 0
            end

            # Apply registration
            Agent.do_work(agent)

            registry = pollers(agent)
            positions = Dict(p.name => idx for (idx, p) in enumerate(registry))

            # Verify ordering (timers < custom < control)
            @test positions[:timers] < positions[:between_timer_control]
            @test positions[:between_timer_control] < positions[:control_stream]
        end

        Agent.on_close(agent)
    end
end

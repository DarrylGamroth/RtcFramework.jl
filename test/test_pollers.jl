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
            pollers = list_pollers(agent)
            @test length(pollers) == 4
            
            # Check that all built-in pollers are registered
            names = [p.name for p in pollers]
            @test :input_streams in names
            @test :properties in names
            @test :timers in names
            @test :control_stream in names
            
            # Verify priority order (lower number = higher priority)
            priorities = [p.priority for p in pollers]
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
            idx = register_poller!(test_poller, agent, 100; name=:test_poller)
            @test idx > 0
            
            # Verify it was added
            pollers = list_pollers(agent)
            @test length(pollers) == 5
            @test any(p -> p.name == :test_poller, pollers)
            
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
            
            # Clear call order and execute
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
            
            # Verify it was registered
            pollers = list_pollers(agent)
            @test any(p -> p.name == :do_block_poller, pollers)
            
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
            
            initial_count = length(list_pollers(agent))
            
            # Unregister it
            result = unregister_poller!(agent, :to_remove)
            @test result == true
            @test length(list_pollers(agent)) == initial_count - 1
            
            # Verify it's gone
            pollers = list_pollers(agent)
            @test !any(p -> p.name == :to_remove, pollers)
            
            # Try to unregister non-existent poller
            result = unregister_poller!(agent, :nonexistent)
            @test result == false
        end

        @testset "Clear all pollers" begin
            # Register some custom pollers
            register_poller!(agent, 100; name=:custom1) do agent; return 0; end
            register_poller!(agent, 200; name=:custom2) do agent; return 0; end
            
            count_before = length(list_pollers(agent))
            @test count_before > 0
            
            # Clear all pollers
            removed_count = clear_pollers!(agent)
            @test removed_count == count_before
            @test length(list_pollers(agent)) == 0
        end

        @testset "List pollers" begin
            # Clear and re-register built-ins
            clear_pollers!(agent)
            Agent.on_start(agent)  # This will re-register built-ins
            
            pollers = list_pollers(agent)
            
            # Verify structure of returned data
            @test pollers isa Vector
            @test length(pollers) >= 4  # At least the 4 built-in pollers
            
            for (idx, poller) in enumerate(pollers)
                @test haskey(poller, :name)
                @test haskey(poller, :priority)
                @test haskey(poller, :position)
                @test poller.position == idx
                @test poller.name isa Symbol
                @test poller.priority isa Int
            end
        end

        @testset "Reordering built-in pollers" begin
            # Clear and re-register
            clear_pollers!(agent)
            Agent.on_start(agent)
            
            # Move control stream to higher priority
            unregister_poller!(agent, :control_stream)
            register_poller!(RtcFramework.control_poller, agent, 25; name=:control_stream)
            
            pollers = list_pollers(agent)
            control_poller = findfirst(p -> p.name == :control_stream, pollers)
            @test pollers[control_poller].priority == 25
            
            # Verify still in sorted order
            priorities = [p.priority for p in pollers]
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
            
            # Test that do_work returns Int
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
            @test isempty(list_pollers(agent))
            
            # After on_start, built-in pollers registered
            Agent.on_start(agent)
            pollers = list_pollers(agent)
            @test length(pollers) == 4
            
            # Verify expected priorities
            poller_map = Dict(p.name => p.priority for p in pollers)
            @test poller_map[:input_streams] < poller_map[:properties]
            @test poller_map[:properties] < poller_map[:timers]
            @test poller_map[:timers] < poller_map[:control_stream]
        end

        @testset "Built-in pollers cleared on close" begin
            Agent.on_start(agent)
            @test !isempty(list_pollers(agent))
            
            Agent.on_close(agent)
            @test isempty(list_pollers(agent))
        end

        @testset "Custom pollers interleave with built-ins" begin
            Agent.on_start(agent)
            
            # Add custom poller between input and property
            register_poller!(agent, 30; name=:between_input_property) do agent
                return 0
            end
            
            pollers = list_pollers(agent)
            positions = Dict(p.name => p.position for p in pollers)
            
            # Verify ordering
            @test positions[:input_streams] < positions[:between_input_property]
            @test positions[:between_input_property] < positions[:properties]
        end

        Agent.on_close(agent)
    end
end

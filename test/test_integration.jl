# Integration test suite for full agent workflows.
# Tests complete agent lifecycle, property publishing workflows, and error scenarios.
function test_integration(client)
    @testset "Complete Agent Lifecycle" begin
        clock = CachedEpochClock(EpochClock())
        properties = TestAgent.Properties(clock)
        comms = CommunicationResources(client, properties)
        base_agent = BaseRtcAgent(comms, properties, clock)
        agent = TestAgent.RtcAgent(base_agent)
        
        # Test full lifecycle from creation to shutdown
        # Note: RtcAgent doesn't have a public state field, test behavior instead
        
        # Open agent
        Agent.on_start(agent)
        @test base(agent).properties !== nothing
        
        # Test agent work processing directly (without AgentRunner threading)
        work_count = Agent.do_work(agent)
        @test work_count isa Int
        
        # Close agent
        Agent.on_close(agent)
    end
    
    @testset "Property Publishing Workflow" begin
        clock = CachedEpochClock(EpochClock())
        properties = TestAgent.Properties(clock)
        comms = CommunicationResources(client, properties)
        base_agent = BaseRtcAgent(comms, properties, clock)
        agent = TestAgent.RtcAgent(base_agent)
        Agent.on_start(agent)
        
        # Test that properties are accessible
        @test base(agent).properties !== nothing
        
        # Test strategy processing works using Agent API
        @test_nowarn Agent.do_work(agent)
        
        Agent.on_close(agent)
    end
    
    @testset "Multi-Agent Scenarios" begin
        # Test multiple agents can coexist
        clock1 = CachedEpochClock(EpochClock())
        properties1 = TestAgent.Properties(clock1)
        comms1 = CommunicationResources(client, properties1)
        base_agent1 = BaseRtcAgent(comms1, properties1, clock1)
        agent1 = TestAgent.RtcAgent(base_agent1)
        clock2 = CachedEpochClock(EpochClock())
        properties2 = TestAgent.Properties(clock2)
        comms2 = CommunicationResources(client, properties2)
        base_agent2 = BaseRtcAgent(comms2, properties2, clock2)
        agent2 = TestAgent.RtcAgent(base_agent2)
        
        Agent.on_start(agent1)
        Agent.on_start(agent2)
        
        # Both agents should be independent and have properties
        @test base(agent1).properties !== nothing
        @test base(agent2).properties !== nothing
        @test base(agent1).properties !== base(agent2).properties  # Different instances
        
        Agent.on_close(agent1)
        Agent.on_close(agent2)
    end
    
    @testset "Performance Validation" begin
        clock = CachedEpochClock(EpochClock())
        properties = TestAgent.Properties(clock)
        comms = CommunicationResources(client, properties)
        base_agent = BaseRtcAgent(comms, properties, clock)
        agent = TestAgent.RtcAgent(base_agent)
        Agent.on_start(agent)
        
        # Transition to Playing state for realistic performance testing
        dispatch!(agent, :Play)
        
        @testset "Basic do_work allocation" begin
            # Warm up
            Agent.do_work(agent)
            Agent.do_work(agent)
            
            # Actual measurement
            allocations = @allocated Agent.do_work(agent)
            @test allocations == 0  # Agent work should be allocation-free
        end
        
        @testset "do_work with timer firing" begin
            # Get the timer periods from properties
            heartbeat_period_ns = base(agent).properties[:HeartbeatPeriodNs]
            stats_period_ns = base(agent).properties[:StatsPeriodNs]
            gc_stats_period_ns = base(agent).properties[:GCStatsPeriodNs]
            
            # Calculate how long we need to run to ensure all timers fire at least once
            max_period_ns = max(heartbeat_period_ns, stats_period_ns, gc_stats_period_ns)
            
            # Warm up phase 1: Run until all timer types have fired at least once
            # This ensures JIT compilation of all timer event handlers
            start_time = Clocks.time_nanos(base(agent).clock)
            elapsed_ns = 0
            
            while elapsed_ns < max_period_ns * 2
                Agent.do_work(agent)
                Clocks.fetch!(base(agent).clock)
                elapsed_ns = Clocks.time_nanos(base(agent).clock) - start_time
            end
            
            # Warm up phase 2: Run additional iterations to stabilize JIT
            for _ in 1:100
                Agent.do_work(agent)
            end
            
            # Now measure allocation with timers firing
            # Run for another full period
            target_duration = max_period_ns
            start_time = Clocks.time_nanos(base(agent).clock)
            elapsed_ns = 0
            total_allocations = 0
            iterations = 0
            
            while elapsed_ns < target_duration
                allocations = @allocated Agent.do_work(agent)
                total_allocations += allocations
                iterations += 1
                Clocks.fetch!(base(agent).clock)
                elapsed_ns = Clocks.time_nanos(base(agent).clock) - start_time
            end
            
            @test iterations > 0  # Sanity check that we actually ran
            
            # We expect zero allocations in Playing state with timers firing after JIT warmup
            # Current implementation shows consistent ~7KB allocation - this is a real issue, not JIT
            avg_alloc = round(total_allocations/iterations, digits=1)
            println("  Timer firing: $total_allocations bytes total over $iterations iterations ($avg_alloc bytes/iteration)")
            
            @test_broken total_allocations == 0  # Known issue: timer handlers allocate
        end
        
        @testset "Heartbeat timer allocation" begin
            # Cancel all timers first
            cancel!(timers(agent))
            
            # Test Heartbeat timer in isolation
            schedule!(timers(agent), 0, :Heartbeat)
            for _ in 1:100
                Agent.do_work(agent)
                schedule!(timers(agent), 0, :Heartbeat)
            end
            
            # Measure single iteration
            schedule!(timers(agent), 0, :Heartbeat)
            heartbeat_alloc = @allocated Agent.do_work(agent)
            println("  Heartbeat: $heartbeat_alloc bytes per iteration")
            
            @test heartbeat_alloc == 0
        end
        
        @testset "StatsUpdate timer allocation" begin
            cancel!(timers(agent))
            
            # Test StatsUpdate timer in isolation
            schedule!(timers(agent), 0, :StatsUpdate)
            for _ in 1:100
                Agent.do_work(agent)
                schedule!(timers(agent), 0, :StatsUpdate)
            end
            
            # Measure single iteration
            schedule!(timers(agent), 0, :StatsUpdate)
            stats_alloc = @allocated Agent.do_work(agent)
            println("  StatsUpdate: $stats_alloc bytes per iteration")
            
            @test stats_alloc == 0  # This should be zero-allocation
        end
        
        @testset "GCStats timer allocation" begin
            cancel!(timers(agent))
            
            # Test GCStats timer in isolation
            schedule!(timers(agent), 0, :GCStats)
            for _ in 1:100
                Agent.do_work(agent)
                schedule!(timers(agent), 0, :GCStats)
            end
            
            # Measure single iteration
            schedule!(timers(agent), 0, :GCStats)
            gc_stats_alloc = @allocated Agent.do_work(agent)
            println("  GCStats: $gc_stats_alloc bytes per iteration")
            
            @test_broken gc_stats_alloc == 0  # Known: Base.gc_num() allocates
        end
        
        @testset "Poller registration/unregistration allocation" begin
            # Test that pollers work correctly and don't allocate after registration
            custom_poller_call_count = Ref(0)
            function custom_poller(agent)
                custom_poller_call_count[] += 1
                return 1  # Report 1 work item
            end
            
            # Warm up to stabilize JIT
            for _ in 1:10
                Agent.do_work(agent)
            end
            
            # Register custom poller - registration is deferred and applied during apply!()
            register!(custom_poller, pollers(agent), :custom_test, 100)
            
            # do_work calls poll() which executes pollers THEN calls apply!()
            # So the first do_work after registration will NOT call the poller yet
            # because apply! happens after polling
            initial_count = custom_poller_call_count[]
            @test initial_count == 0
            
            Agent.do_work(agent)  # This applies the registration but doesn't call it
            @test custom_poller_call_count[] == 0  # Not called yet
            
            # Second do_work will call the poller since it's now registered
            Agent.do_work(agent)
            @test custom_poller_call_count[] == 1  # Now it should be called
            
            # After registration is applied, subsequent calls should not allocate
            # Run a few times to verify consistent zero allocation
            allocation_warned = false
            for _ in 1:5
                Agent.do_work(agent)
                allocations = @allocated Agent.do_work(agent)
                if allocations > 0 && !allocation_warned
                    @warn "Poller execution allocated $allocations bytes (ideally should be 0)"
                    allocation_warned = true
                end
            end
            
            # Verify poller has been called multiple times
            @test custom_poller_call_count[] > 5
            
            # Unregister - this is also deferred
            unregister!(pollers(agent), :custom_test)
            
            # One do_work to apply the unregistration (but poller still called during this one)
            pre_unreg_count = custom_poller_call_count[]
            Agent.do_work(agent)  # Poller runs, THEN unregister is applied
            
            # Now poller should not be called anymore
            post_apply_count = custom_poller_call_count[]
            Agent.do_work(agent)
            Agent.do_work(agent)
            @test custom_poller_call_count[] == post_apply_count  # No new calls
        end
        
        Agent.on_close(agent)
    end
end

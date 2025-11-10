"""
Test suite for Timer system functionality.
Tests timer scheduling, cancellation, and polling.
"""
function test_timers(client)
    @testset "Timer Basic Operations" begin
        clock = CachedEpochClock(EpochClock())
        timers = PolledTimer(clock)
        
        # Test initial state
        @test length(timers) == 0
        @test isempty(timers)
        
        # Test timer scheduling
        timer_id = schedule!(timers, 1_000_000, :TestEvent)
        @test timer_id > 0
        @test length(timers) == 1
        @test !isempty(timers)
        
        # Test timer cancellation
        cancel!(timers, timer_id)
        @test length(timers) == 0
        @test isempty(timers)
    end
    
    @testset "Timer Integration with Agent" begin
        clock = CachedEpochClock(EpochClock())
        properties = TestAgent.Properties(clock)
        comms = CommunicationResources(client, properties)
        base_agent = BaseRtcAgent(comms, properties, clock)
        agent = TestAgent.RtcAgent(base_agent)
        
        # Initialize the agent to set up proxies
        Agent.on_start(agent)
        
        # Test that agent has timer system
        @test !isnothing(base(agent).timers)
        @test base(agent).timers isa PolledTimer
        
        # Test timer polling (should not error)
        @test_nowarn RtcFramework.timer_poller(agent)
        
        # Clean up
        Agent.on_close(agent)
    end
    
    @testset "Timer Exceptions" begin
        # Test TimerNotFoundError
        err = RtcFramework.Timers.TimerNotFoundError(12345)
        @test err.timer_id == 12345
        
        io = IOBuffer()
        showerror(io, err)
        msg = String(take!(io))
        @test contains(msg, "TimerNotFoundError")
        @test contains(msg, "12345")
        
        # Test InvalidTimerError
        err = RtcFramework.Timers.InvalidTimerError("Invalid deadline")
        @test err.message == "Invalid deadline"
        
        io = IOBuffer()
        showerror(io, err)
        msg = String(take!(io))
        @test contains(msg, "InvalidTimerError")
        @test contains(msg, "Invalid deadline")
        
        # Test TimerSchedulingError
        err = RtcFramework.Timers.TimerSchedulingError("Deadline in past", 1000)
        @test err.message == "Deadline in past"
        @test err.deadline == 1000
        
        io = IOBuffer()
        showerror(io, err)
        msg = String(take!(io))
        @test contains(msg, "TimerSchedulingError")
        @test contains(msg, "Deadline in past")
        @test contains(msg, "1000")
        
        # Test exception type hierarchy
        @test RtcFramework.Timers.TimerNotFoundError <: RtcFramework.Timers.TimerError
        @test RtcFramework.Timers.InvalidTimerError <: RtcFramework.Timers.TimerError
        @test RtcFramework.Timers.TimerSchedulingError <: RtcFramework.Timers.TimerError
        @test RtcFramework.Timers.TimerError <: Exception
    end
    
    # Additional timer tests would go here
    # - Timer firing tests (with clock mocking)
    # - Multiple timer management
    # - Timer event dispatch integration
end

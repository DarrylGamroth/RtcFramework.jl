# Test suite for exception handling system.
# Tests custom exception types and error handling workflows.
function test_exceptions(client) 
    @testset "Error Message Quality" begin
        # Basic test that error handling works without exposing internal types
        clock = CachedEpochClock(EpochClock())
        properties = TestAgent.Properties(clock)
        comms = CommunicationResources(client, properties)
        base_agent = BaseRtcAgent(comms, properties, clock)
        agent = TestAgent.RtcAgent(base_agent)
        
        # This should throw an informative error
        try
            start(agent)  # Invalid state transition
            @test false  # Should have thrown an exception
        catch e
            @test e isa Exception
            @test !isempty(string(e))  # Error message should not be empty
        end
        
        Agent.on_close(agent)
    end

    @testset "AgentStateError" begin
        err = RtcFramework.AgentStateError(:Stopped, "start operation")
        @test err.current_state == :Stopped
        @test err.attempted_operation == "start operation"
        
        # Test error message formatting
        io = IOBuffer()
        showerror(io, err)
        msg = String(take!(io))
        @test contains(msg, "AgentStateError")
        @test contains(msg, "start operation")
        @test contains(msg, "Stopped")
    end

    @testset "AgentCommunicationError" begin
        err = RtcFramework.AgentCommunicationError("Failed to initialize Aeron")
        @test err.message == "Failed to initialize Aeron"
        
        io = IOBuffer()
        showerror(io, err)
        msg = String(take!(io))
        @test contains(msg, "AgentCommunicationError")
        @test contains(msg, "Failed to initialize Aeron")
    end

    @testset "AgentConfigurationError" begin
        err = RtcFramework.AgentConfigurationError("Missing required configuration")
        @test err.message == "Missing required configuration"
        
        io = IOBuffer()
        showerror(io, err)
        msg = String(take!(io))
        @test contains(msg, "AgentConfigurationError")
        @test contains(msg, "Missing required configuration")
    end

    @testset "PublicationError" begin
        err = RtcFramework.PublicationError("Buffer claim failed", :my_property)
        @test err.message == "Buffer claim failed"
        @test err.field == :my_property
        
        io = IOBuffer()
        showerror(io, err)
        msg = String(take!(io))
        @test contains(msg, "PublicationError")
        @test contains(msg, "my_property")
        @test contains(msg, "Buffer claim failed")
    end

    @testset "ClaimBufferError" begin
        err = RtcFramework.ClaimBufferError("pub://test", 1024, 5)
        @test err.publication == "pub://test"
        @test err.length == 1024
        @test err.max_attempts == 5
        
        io = IOBuffer()
        showerror(io, err)
        msg = String(take!(io))
        @test contains(msg, "ClaimBufferError")
        @test contains(msg, "1024")
        @test contains(msg, "pub://test")
        @test contains(msg, "5")
    end

    @testset "PublicationBackPressureError" begin
        err = RtcFramework.PublicationBackPressureError("pub://test", 10)
        @test err.publication == "pub://test"
        @test err.max_attempts == 10
        
        io = IOBuffer()
        showerror(io, err)
        msg = String(take!(io))
        @test contains(msg, "PublicationBackPressureError")
        @test contains(msg, "pub://test")
        @test contains(msg, "10")
        @test contains(msg, "back pressure")
    end

    @testset "StreamNotFoundError" begin
        err = RtcFramework.StreamNotFoundError("data_stream", 42)
        @test err.stream_name == "data_stream"
        @test err.stream_index == 42
        
        io = IOBuffer()
        showerror(io, err)
        msg = String(take!(io))
        @test contains(msg, "StreamNotFoundError")
        @test contains(msg, "data_stream")
        @test contains(msg, "42")
    end

    @testset "CommunicationNotInitializedError" begin
        err = RtcFramework.CommunicationNotInitializedError("publish")
        @test err.operation == "publish"
        
        io = IOBuffer()
        showerror(io, err)
        msg = String(take!(io))
        @test contains(msg, "CommunicationNotInitializedError")
        @test contains(msg, "publish")
        @test contains(msg, "not initialized")
    end

    @testset "PublicationFailureError" begin
        err = RtcFramework.PublicationFailureError("pub://test", 3)
        @test err.publication == "pub://test"
        @test err.max_attempts == 3
        
        io = IOBuffer()
        showerror(io, err)
        msg = String(take!(io))
        @test contains(msg, "PublicationFailureError")
        @test contains(msg, "pub://test")
        @test contains(msg, "3")
    end

    @testset "ClaimBackPressureError" begin
        err = RtcFramework.ClaimBackPressureError("pub://test", 2048, 7)
        @test err.publication == "pub://test"
        @test err.length == 2048
        @test err.max_attempts == 7
        
        io = IOBuffer()
        showerror(io, err)
        msg = String(take!(io))
        @test contains(msg, "ClaimBackPressureError")
        @test contains(msg, "2048")
        @test contains(msg, "pub://test")
        @test contains(msg, "7")
        @test contains(msg, "back pressure")
    end

    @testset "PropertyNotFoundError" begin
        err = RtcFramework.PropertyNotFoundError(:missing_prop)
        @test err.property_name == :missing_prop
        
        io = IOBuffer()
        showerror(io, err)
        msg = String(take!(io))
        @test contains(msg, "PropertyNotFoundError")
        @test contains(msg, "missing_prop")
    end

    @testset "PropertyTypeError" begin
        err = RtcFramework.PropertyTypeError(:my_prop, Int, String)
        @test err.property_name == :my_prop
        @test err.expected_type == Int
        @test err.actual_type == String
        
        io = IOBuffer()
        showerror(io, err)
        msg = String(take!(io))
        @test contains(msg, "PropertyTypeError")
        @test contains(msg, "my_prop")
        @test contains(msg, "Int")
        @test contains(msg, "String")
    end

    @testset "PropertyAccessError" begin
        err = RtcFramework.PropertyAccessError(:read_only_prop, "read-only")
        @test err.property_name == :read_only_prop
        @test err.access_mode == "read-only"
        
        io = IOBuffer()
        showerror(io, err)
        msg = String(take!(io))
        @test contains(msg, "PropertyAccessError")
        @test contains(msg, "read_only_prop")
        @test contains(msg, "read-only")
    end

    @testset "PropertyValidationError" begin
        err = RtcFramework.PropertyValidationError(:value, "must be positive")
        @test err.property_name == :value
        @test err.message == "must be positive"
        
        io = IOBuffer()
        showerror(io, err)
        msg = String(take!(io))
        @test contains(msg, "PropertyValidationError")
        @test contains(msg, "value")
        @test contains(msg, "must be positive")
    end

    @testset "EnvironmentVariableError" begin
        err = RtcFramework.EnvironmentVariableError("REQUIRED_VAR")
        @test err.variable_name == "REQUIRED_VAR"
        
        io = IOBuffer()
        showerror(io, err)
        msg = String(take!(io))
        @test contains(msg, "EnvironmentVariableError")
        @test contains(msg, "REQUIRED_VAR")
    end

    @testset "Exception Type Hierarchy" begin
        # Test that exceptions have the correct parent types
        @test RtcFramework.AgentStateError <: RtcFramework.AgentError
        @test RtcFramework.AgentCommunicationError <: RtcFramework.AgentError
        @test RtcFramework.AgentConfigurationError <: RtcFramework.AgentError
        @test RtcFramework.PublicationError <: RtcFramework.AgentError
        @test RtcFramework.AgentError <: Exception
        
        @test RtcFramework.ClaimBufferError <: RtcFramework.CommunicationError
        @test RtcFramework.PublicationBackPressureError <: RtcFramework.CommunicationError
        @test RtcFramework.StreamNotFoundError <: RtcFramework.CommunicationError
        @test RtcFramework.CommunicationNotInitializedError <: RtcFramework.CommunicationError
        @test RtcFramework.PublicationFailureError <: RtcFramework.CommunicationError
        @test RtcFramework.ClaimBackPressureError <: RtcFramework.CommunicationError
        @test RtcFramework.CommunicationError <: RtcFramework.AgentError
        
        @test RtcFramework.PropertyNotFoundError <: RtcFramework.PropertyError
        @test RtcFramework.PropertyTypeError <: RtcFramework.PropertyError
        @test RtcFramework.PropertyAccessError <: RtcFramework.PropertyError
        @test RtcFramework.PropertyValidationError <: RtcFramework.PropertyError
        @test RtcFramework.EnvironmentVariableError <: RtcFramework.PropertyError
        @test RtcFramework.PropertyError <: Exception
    end
end

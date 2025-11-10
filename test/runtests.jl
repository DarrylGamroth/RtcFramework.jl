using Test
using RtcFramework
using Aeron
using Agent
using Clocks
using SnowflakeId
using StaticKV
using WrappedUnions

# Load TestAgent module for tests
include("TestAgent.jl")
using .TestAgent

# Set up test environment variables before loading TestAgent
ENV["BLOCK_NAME"] = "TestAgent"
ENV["BLOCK_ID"] = "1"
ENV["STATUS_URI"] = "aeron:ipc"
ENV["STATUS_STREAM_ID"] = "1001"
ENV["CONTROL_URI"] = "aeron:ipc"
ENV["CONTROL_STREAM_ID"] = "1002"
ENV["HEARTBEAT_PERIOD_NS"] = "5000000000"
ENV["LOG_LEVEL"] = "Error"  # Reduce log noise during tests
ENV["GC_LOGGING"] = "false"

# Set up minimal pub/sub data connections for testing
ENV["PUB_DATA_URI_1"] = "aeron:ipc"
ENV["PUB_DATA_STREAM_1"] = "2001"
ENV["PUB_DATA_URI_2"] = "aeron:ipc"
ENV["PUB_DATA_STREAM_2"] = "2002"
ENV["SUB_DATA_URI_1"] = "aeron:ipc"
ENV["SUB_DATA_STREAM_1"] = "3001"
ENV["SUB_DATA_URI_2"] = "aeron:ipc"
ENV["SUB_DATA_STREAM_2"] = "3002"

# Include individual test modules
include("test_strategies.jl")
include("test_counters.jl")
include("test_rtcagent.jl")
include("test_adapters.jl")
include("test_property_publishing.jl")
include("test_property_registration.jl")
include("test_communications.jl")
include("test_property_store.jl")
include("test_timers.jl")
include("test_exceptions.jl")
include("test_pollers.jl")
include("test_accessors.jl")
include("test_states.jl")
include("test_integration.jl")
include("test_onupdate_integration.jl")
include("test_proxy_allocations.jl")

# Run all test suites with organized structure
@testset "RtcFramework.jl Tests" begin
    # Tests that don't need Aeron context
    @testset "Strategy System Tests" begin
        test_strategies()
    end

    @testset "PropertyStore Tests" begin
        test_property_store()
    end

    # Tests that need shared Aeron context
    MediaDriver.launch_embedded() do driver
        Aeron.Context() do context
            Aeron.aeron_dir!(context, MediaDriver.aeron_dir(driver))
            Aeron.Client(context) do client
                @testset "Counter System Tests" begin
                    test_counters(client)
                end

                @testset "RtcAgent Core Tests" begin
                    test_rtcagent(client)
                end

                @testset "Stream Adapter Tests" begin
                    test_adapters(client)
                end

                @testset "Property Publishing Tests" begin
                    test_property_publishing(client)
                end

                @testset "Property Registration Tests" begin
                    test_property_registration(client)
                end

                @testset "Communications Tests" begin
                    test_communications(client)
                end

                @testset "Timer System Tests" begin
                    test_timers(client)
                end

                @testset "Poller System Tests" begin
                    test_pollers(client)
                end

                @testset "Accessor Function Tests" begin
                    test_accessors(client)
                end

                @testset "Exception Handling Tests" begin
                    test_exceptions(client)
                end

                @testset "State Machine Tests" begin
                    test_states(client)
                end

                @testset "Integration Tests" begin
                    test_integration(client)
                end

                @testset "OnUpdate Integration Tests" begin
                    test_onupdate_with_cached_timer(client)
                end

                @testset "Proxy Allocation Tests" begin
                    test_proxy_allocations.run_tests(client)
                end
            end
        end
    end
end

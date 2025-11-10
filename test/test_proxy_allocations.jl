module test_proxy_allocations

using Test
using RtcFramework
using Aeron
using SpidersMessageCodecs

# Helper to create a test status proxy with subscriber
function create_test_status_proxy(client::Aeron.Client)
    pub = Aeron.add_exclusive_publication(client, "aeron:ipc", 1001)
    # Add subscriber so try_claim will work
    sub = Aeron.add_subscription(client, "aeron:ipc", 1001)
    RtcFramework.StatusProxy(pub), sub
end

# Helper to create a test property proxy with subscribers
function create_test_property_proxy(client::Aeron.Client)
    pub1 = Aeron.add_exclusive_publication(client, "aeron:ipc", 2001)
    pub2 = Aeron.add_exclusive_publication(client, "aeron:ipc", 2002)
    # Add subscribers so try_claim will work
    sub1 = Aeron.add_subscription(client, "aeron:ipc", 2001)
    sub2 = Aeron.add_subscription(client, "aeron:ipc", 2002)
    RtcFramework.PropertyProxy([pub1, pub2]), (sub1, sub2)
end

function run_tests(client::Aeron.Client)
    @testset "StatusProxy - publish_status_event" begin
        proxy, sub = create_test_status_proxy(client)
        
        # Test Int64
        @testset "Int64 values" begin
            # Warm up
            for _ in 1:100
                RtcFramework.publish_status_event(proxy, :test, 42, "tag", 1, 1000)
            end
            alloc = @allocated RtcFramework.publish_status_event(proxy, :test, 42, "tag", 1, 1000)
            @test alloc == 0
        end
        
        # Test Float64
        @testset "Float64 values" begin
            for _ in 1:100
                RtcFramework.publish_status_event(proxy, :test, 3.14, "tag", 1, 1000)
            end
            alloc = @allocated RtcFramework.publish_status_event(proxy, :test, 3.14, "tag", 1, 1000)
            @test alloc == 0
        end
        
        # Test Symbol
        @testset "Symbol values" begin
            for _ in 1:100
                RtcFramework.publish_status_event(proxy, :test, :symbol, "tag", 1, 1000)
            end
            alloc = @allocated RtcFramework.publish_status_event(proxy, :test, :symbol, "tag", 1, 1000)
            @test alloc == 0
        end
        
        # Test Bool
        @testset "Bool values" begin
            for _ in 1:100
                RtcFramework.publish_status_event(proxy, :test, true, "tag", 1, 1000)
            end
            alloc = @allocated RtcFramework.publish_status_event(proxy, :test, true, "tag", 1, 1000)
            @test alloc == 0
        end
        
        # Test Nothing
        @testset "Nothing values" begin
            for _ in 1:100
                RtcFramework.publish_status_event(proxy, :test, nothing, "tag", 1, 1000)
            end
            alloc = @allocated RtcFramework.publish_status_event(proxy, :test, nothing, "tag", 1, 1000)
            @test alloc == 0
        end
        
        # Test String - actually zero-allocation!
        @testset "String values" begin
            for _ in 1:100
                RtcFramework.publish_status_event(proxy, :test, "hello", "tag", 1, 1000)
            end
            alloc = @allocated RtcFramework.publish_status_event(proxy, :test, "hello", "tag", 1, 1000)
            @test alloc == 0
        end
        
        # Test Array{Int64} - actually zero-allocation!
        @testset "Array{Int64} values" begin
            arr = [1, 2, 3, 4, 5]
            for _ in 1:100
                RtcFramework.publish_status_event(proxy, :test, arr, "tag", 1, 1000)
            end
            alloc = @allocated RtcFramework.publish_status_event(proxy, :test, arr, "tag", 1, 1000)
            @test alloc == 0
        end
        
        # Test Array{Float64} - actually zero-allocation!
        @testset "Array{Float64} values" begin
            arr = [1.0, 2.0, 3.0, 4.0, 5.0]
            for _ in 1:100
                RtcFramework.publish_status_event(proxy, :test, arr, "tag", 1, 1000)
            end
            alloc = @allocated RtcFramework.publish_status_event(proxy, :test, arr, "tag", 1, 1000)
            @test alloc == 0
        end
    end
    
    @testset "StatusProxy - publish_state_change" begin
        proxy, sub = create_test_status_proxy(client)
        
        for _ in 1:100
            RtcFramework.publish_state_change(proxy, :Playing, "tag", 1, 1000)
        end
        alloc = @allocated RtcFramework.publish_state_change(proxy, :Playing, "tag", 1, 1000)
        @test alloc == 0
    end
    
    @testset "StatusProxy - publish_event_response" begin
        proxy, sub = create_test_status_proxy(client)
        
        # Test with Bool
        @testset "Bool response" begin
            for _ in 1:100
                RtcFramework.publish_event_response(proxy, :Heartbeat, true, "tag", 1, 1000)
            end
            alloc = @allocated RtcFramework.publish_event_response(proxy, :Heartbeat, true, "tag", 1, 1000)
            @test alloc == 0
        end
        
        # Test with Int
        @testset "Int response" begin
            for _ in 1:100
                RtcFramework.publish_event_response(proxy, :Heartbeat, 42, "tag", 1, 1000)
            end
            alloc = @allocated RtcFramework.publish_event_response(proxy, :Heartbeat, 42, "tag", 1, 1000)
            @test alloc == 0
        end
        
        # Test with Symbol
        @testset "Symbol response" begin
            for _ in 1:100
                RtcFramework.publish_event_response(proxy, :Heartbeat, :ok, "tag", 1, 1000)
            end
            alloc = @allocated RtcFramework.publish_event_response(proxy, :Heartbeat, :ok, "tag", 1, 1000)
            @test alloc == 0
        end
        
        # Test with Float64
        @testset "Float64 response" begin
            for _ in 1:100
                RtcFramework.publish_event_response(proxy, :Heartbeat, 3.14, "tag", 1, 1000)
            end
            alloc = @allocated RtcFramework.publish_event_response(proxy, :Heartbeat, 3.14, "tag", 1, 1000)
            @test alloc == 0
        end
    end
    
    @testset "PropertyProxy - publish_property" begin
        proxy, subs = create_test_property_proxy(client)
        
        # Test Int64
        @testset "Int64 values" begin
            for _ in 1:100
                RtcFramework.publish_property(proxy, 1, :test, 42, "tag", 1, 1000)
            end
            alloc = @allocated RtcFramework.publish_property(proxy, 1, :test, 42, "tag", 1, 1000)
            @test alloc == 0
        end
        
        # Test Float64
        @testset "Float64 values" begin
            for _ in 1:100
                RtcFramework.publish_property(proxy, 1, :test, 3.14, "tag", 1, 1000)
            end
            alloc = @allocated RtcFramework.publish_property(proxy, 1, :test, 3.14, "tag", 1, 1000)
            @test alloc == 0
        end
        
        # Test Symbol
        @testset "Symbol values" begin
            for _ in 1:100
                RtcFramework.publish_property(proxy, 1, :test, :symbol, "tag", 1, 1000)
            end
            alloc = @allocated RtcFramework.publish_property(proxy, 1, :test, :symbol, "tag", 1, 1000)
            @test alloc == 0
        end
        
        # Test Bool
        @testset "Bool values" begin
            for _ in 1:100
                RtcFramework.publish_property(proxy, 1, :test, true, "tag", 1, 1000)
            end
            alloc = @allocated RtcFramework.publish_property(proxy, 1, :test, true, "tag", 1, 1000)
            @test alloc == 0
        end
        
        # Test Nothing
        @testset "Nothing values" begin
            for _ in 1:100
                RtcFramework.publish_property(proxy, 1, :test, nothing, "tag", 1, 1000)
            end
            alloc = @allocated RtcFramework.publish_property(proxy, 1, :test, nothing, "tag", 1, 1000)
            @test alloc == 0
        end
        
        # Test String - actually zero-allocation!
        @testset "String values" begin
            for _ in 1:100
                RtcFramework.publish_property(proxy, 1, :test, "hello", "tag", 1, 1000)
            end
            alloc = @allocated RtcFramework.publish_property(proxy, 1, :test, "hello", "tag", 1, 1000)
            @test alloc == 0
        end
        
        # Test Array{Int64} - actually zero-allocation!
        @testset "Array{Int64} values" begin
            arr = [1, 2, 3, 4, 5]
            for _ in 1:100
                RtcFramework.publish_property(proxy, 1, :test, arr, "tag", 1, 1000)
            end
            alloc = @allocated RtcFramework.publish_property(proxy, 1, :test, arr, "tag", 1, 1000)
            @test alloc == 0
        end
        
        # Test Array{Float64} - actually zero-allocation!
        @testset "Array{Float64} values" begin
            arr = [1.0, 2.0, 3.0, 4.0, 5.0]
            for _ in 1:100
                RtcFramework.publish_property(proxy, 1, :test, arr, "tag", 1, 1000)
            end
            alloc = @allocated RtcFramework.publish_property(proxy, 1, :test, arr, "tag", 1, 1000)
            @test alloc == 0
        end
    end
    
    @testset "PropertyProxy - Multiple streams" begin
        proxy, subs = create_test_property_proxy(client)
        
        # Warm up both streams
        for _ in 1:100
            RtcFramework.publish_property(proxy, 1, :test, 42, "tag", 1, 1000)
            RtcFramework.publish_property(proxy, 2, :test, 42, "tag", 1, 1000)
        end
        
        # Test stream 1
        alloc1 = @allocated RtcFramework.publish_property(proxy, 1, :test, 42, "tag", 1, 1000)
        @test alloc1 == 0
        
        # Test stream 2
        alloc2 = @allocated RtcFramework.publish_property(proxy, 2, :test, 42, "tag", 1, 1000)
        @test alloc2 == 0
    end
end

end # module test_proxy_allocations

module TestService

using RtcFramework

using Aeron
using Agent
using Clocks
using Hsm
using Logging
using StaticKV
using ThreadPinning

ENV["STATUS_URI"] = "aeron:udp?endpoint=0.0.0.0:40123"
ENV["STATUS_STREAM_ID"] = "1"
ENV["CONTROL_URI"] = "aeron-spy:aeron:udp?endpoint=0.0.0.0:40123"
ENV["CONTROL_STREAM_ID"] = "2"
ENV["CONTROL_FILTER"] = "TestService"
ENV["PUB_DATA_URI_1"] = "aeron:udp?endpoint=localhost:40123|term-length=128m"
ENV["PUB_DATA_STREAM_1"] = "12"
ENV["BLOCK_NAME"] = "TestService"
ENV["BLOCK_ID"] = "367"
ENV["SUB_DATA_URI_1"] = "aeron:udp?endpoint=0.0.0.0:40123"
ENV["SUB_DATA_STREAM_1"] = "4"
ENV["LOG_LEVEL"] = "Debug"

import RtcFramework: PropertyStore.generate_sub_data_uri_keys, PropertyStore.generate_pub_data_uri_keys

include("myagent.jl")
include("kvstore.jl")

export main

Base.exit_on_sigint(false)

function main()
    pinthreads(:affinitymask)

    launch_driver = parse(Bool, get(ENV, "LAUNCH_MEDIA_DRIVER", "false"))

    if launch_driver
        @info "Launching Aeron MediaDriver"
        Aeron.MediaDriver.launch() do
            run_agent()
        end
    else
        @info "Running with external MediaDriver"
        run_agent()
    end

    return 0
end

function run_agent()
    Aeron.Context() do context
        Aeron.Client(context) do client
            clock = CachedEpochClock(EpochClock())
            properties = Properties(clock)

            # Create communication resources
            comms = RtcFramework.CommunicationResources(client, properties)

            # Inject communication resources into the agent
            base = RtcFramework.BaseRtcAgent(comms, properties, clock)

            agent = MyAgent(base)

            # Start the agent
            runner = AgentRunner(BackoffIdleStrategy(), agent)

            Agent.start_on_thread(runner, 3)

            try
                wait(runner)
            catch e
                if e isa InterruptException
                    @info "Shutting down..."
                else
                    @error "Exception caught:" exception = (e, catch_backtrace())
                end
            finally
                close(runner)
            end
        end
    end
end

ctx = Aeron.Context()
client = Aeron.Client(ctx)
clock = CachedEpochClock(EpochClock())
properties = Properties(clock)

# Create communication resources
comms = RtcFramework.CommunicationResources(client, properties)
base = RtcFramework.BaseRtcAgent(comms, properties, clock)
agent = MyAgent(base)

end # module TestService
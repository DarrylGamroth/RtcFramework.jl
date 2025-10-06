module PropertyStore

using Logging
using StaticKV

export PropertyError, PropertyNotFoundError, PropertyTypeError, PropertyAccessError, PropertyValidationError, EnvironmentVariableError, @generate_sub_data_uri_keys, @generate_pub_data_uri_keys

include("exceptions.jl")
include("utilities.jl")

end # module PropertyStore
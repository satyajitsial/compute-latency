-- schema.lua
return {
  name = "compute-latency",
  fields = {
    {
      config = {
	    type = "record",
        fields = {
          { plugin_suffix = { type = "string", encrypted = true, default = "-execution-time", required = true}}
        },
    },
  },
},
}


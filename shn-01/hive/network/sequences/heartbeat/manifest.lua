return {
  name = "heartbeat",
  version = "1.0",
  dependencies = {},
  server = "server.lua",
  client = "client.lua",
  timeout = 0,  -- No timeout - runs indefinitely until node disconnects
  description = "Heartbeat sequence that maintains persistent connection monitoring",
  sequence = true,
}

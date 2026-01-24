-- Event system
globalEvents = {}
-- Called every execution tick
globalEvents.onTick = new("/shn-01/core/event")
-- When a key is pressed
globalEvents.onKeyDown = new("/shn-01/core/event")
-- When a key is released
globalEvents.onKeyUp = new("/shn-01/core/event")
-- When a network message was received
globalEvents.onNetMessageReceived = new("/shn-01/core/event")
-- Unhandled signal received
globalEvents.onSignal = new("/shn-01/core/event")
-- Screen was touched
globalEvents.onTouch = new("/shn-01/core/event")
-- Stopped dragging here
globalEvents.onDrop = new("/shn-01/core/event")
-- Dragging across
globalEvents.onDrag = new("/shn-01/core/event")
-- Scrolling
globalEvents.onScroll = new("/shn-01/core/event")
-- When the system is ready to use
globalEvents.onSystemReady = new("/shn-01/core/event")

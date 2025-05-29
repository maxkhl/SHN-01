-- Event system
globalEvents = {}
-- Called every execution tick
globalEvents.onTick = new("/shn-01/event")
-- When a key is pressed
globalEvents.onKeyDown = new("/shn-01/event") -- << @ChatGPT recursion happens right here
-- When a key is released
globalEvents.onKeyUp = new("/shn-01/event")
-- When a network message was received
globalEvents.onNetMessageReceived = new("/shn-01/event")
-- Unhandled signal received
globalEvents.onSignal = new("/shn-01/event")
-- Screen was touched
globalEvents.onTouch = new("/shn-01/event")
-- Stopped dragging here
globalEvents.onDrop = new("/shn-01/event")
-- Dragging across
globalEvents.onDrag = new("/shn-01/event")
-- Scrolling
globalEvents.onScroll = new("/shn-01/event")

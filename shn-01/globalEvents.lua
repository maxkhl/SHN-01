-- Event system
globalEvents = {}
-- Called every execution tick
globalEvents.onTick = new("/shn-01/eventClass.lua")
-- When a key is pressed
globalEvents.onKeyDown = new("/shn-01/eventClass.lua")
-- When a key is released
globalEvents.onKeyUp = new("/shn-01/eventClass.lua")
-- When a network message was received
globalEvents.onNetMessageReceived = new("/shn-01/eventClass.lua")
-- Unhandled signal received
globalEvents.onSignal = new("/shn-01/eventClass.lua")
-- Screen was touched
globalEvents.onTouch = new("/shn-01/eventClass.lua")
-- Stopped dragging here
globalEvents.onDrop = new("/shn-01/eventClass.lua")
-- Dragging across
globalEvents.onDrag = new("/shn-01/eventClass.lua")
-- Scrolling
globalEvents.onScroll = new("/shn-01/eventClass.lua")

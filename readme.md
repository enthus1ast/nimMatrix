some procs to speak to a matrix chat server
i'll add stuff when i need it.

- No encryption (yet?)
- Async AND Sync client.
- Bot example in bot.nim and asyncBot.nim


two modes of operandi:

1. you call eg. matrix.events() in a loop and handle the events yourself (most lowlevel).
2. ~~you create a `EventHandler`, fill its callbacks (like room invite, message etc.) and let the event handler call matrix.events() for you.~~ (not yet implemented)



TODO
-----

- [ ] uploadFile procs should stream the data
- [ ] encryption

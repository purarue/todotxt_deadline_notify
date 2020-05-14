# TodotxtDeadlineNotify

A companion for [full_todotxt](https://github.com/seanbreckenridge/full_todotxt), runs on my server and sends me reminders when `deadlines` for `todos` when they get close. In particular:

- In the morning: remind me of any todos which have `deadline`s today.
- In the evening: remind me of any todos (excluding priority `C`) for tomorrow.
- For each todo, remind me some time before the todos `deadline` If:
  - Priority is (A), 2 hour before deadline
  - Priority is (B), 1 hour before deadline
  - Priority is (C) or None, 0.5 hours before

When to remind in the morning/evening (and the timezone) is configured in [`config/config.exs`](./config/config.exs)

Currently this notifies me by sending me a message through a discord web hook, the configuration is setup in `config`. This isn't necessarily a server, lots of those [already exist](https://github.com/todotxt/todo.txt-cli/wiki/Other-Todo.txt-Projects). This doesn't offer a mechanism to get your current `todo.txt` up to the server, you can use one of the existing servers or just have your own solution to `scp` it up to a server periodically/after you edit it.

In the background, I run:

```
find ~/.config/todo/todo.txt | entr scp ...
```

... which `scp`s my `todo.txt` up to my server whenever its saved.

The discord web hook and location of todo.txt on the server are hard coded in `config`.

This could be extended pretty easily, by modifying the `notify` function [here](./todotxt_deadline_notify/lib/notify.ex) to send the message to somewhere other than discord.

# TodotxtDeadlineNotify

A companion for [full_todotxt](https://github.com/seanbreckenridge/full_todotxt), runs on my server and sends me reminders when `deadlines` for `todos` when they get close. In particular:

- In the morning: remind me of any todos which have `deadline`s today.
- In the evening: remind me of any todos (excluding priority `C`) for tomorrow.
- For each todo, remind me some time before the todos `deadline` If:
  - Priority is (A), 2 hour before deadline
  - Priority is (B), 1 hour before deadline
  - Priority is (C) or None, 0.5 hours before

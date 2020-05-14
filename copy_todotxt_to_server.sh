#!/bin/bash

TODO_FILE="${HOME}/.config/todo/todo.txt"
SSH_KEYFILE="${HOME}/.ssh/vultr"

find "$TODO_FILE" | entr scp -v -o IPQoS=0 -i "$SSH_KEYFILE" "$TODO_FILE" "$USER"@140.82.50.43:.todo/todo.txt


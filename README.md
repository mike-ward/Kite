# Kite

A Bluesky readonly desktop-client written in the V programming language.
Its intended use is as a desktop gadget that sits to one side of your screen.
Kite is not meant to be a full-featured desktop application, but rather a lightweight tool for browsing Bluesky posts.
Reacting or replying to posts is not supported. Instead, click on the post title to open the post in your browser.

![Screenshot](screenshot.png)

## Features
- Updates timeline every minute
- Displays images that are part of the original post.
- Posts are displayed in a compact format by removing extra linebreaks and whitespace.

## Installing
Install the V compiler from https://vlang.io

```
git clone https://github.com/mike-ward/Kite
cd kite
v install ui
v run .
```

Kite relies on V's V-UI library, which is still in development.

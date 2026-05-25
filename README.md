# StepDown

StepDown is a small GNUstep/Cocoa Markdown viewer and creator written in
Objective-C using Objective-C 1.0 style. It provides a split editor/preview
window, file open/save/save-as, and live Markdown rendering without WebKit.

## Features

- Create, edit, open, and save Markdown files.
- Live rendered preview using `NSAttributedString`.
- Basic Markdown support: headings, bullets, numbered lists, block quotes,
  code blocks, horizontal rules, links, inline code, bold, and italic text.
- Programmatic AppKit UI, with no nib or storyboard dependency.
- Manual retain/release memory management.

## Screenshots

On macOS:
<img width="1169" height="808" alt="md-demo-mac" src="https://github.com/user-attachments/assets/518ec7d0-9d56-47e7-af10-21d39e710a92" />

On GNUstep:
<img width="1239" height="833" alt="md-demo-gs" src="https://github.com/user-attachments/assets/0ddd51c4-8172-44ee-aa9b-7cb050f7e364" />

## Build On GNUstep/Linux

Install GNUstep development packages, then run:

```sh
make
```

If your distribution uses GNUstep Make, this also works:

```sh
make -f GNUmakefile
```

Run:

```sh
./obj/StepDown
```

or, with GNUstep Make:

```sh
openapp ./StepDown.app
```

## Build On macOS

Run:

```sh
make
```

Run:

```sh
open build/StepDown.app
```

## Notes

The renderer is intentionally native and conservative rather than a complete
CommonMark implementation. This keeps the application portable across Cocoa and
GNUstep without requiring WebKit or external Markdown libraries.

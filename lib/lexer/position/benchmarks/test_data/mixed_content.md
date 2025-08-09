# Mixed Content Markdown

## Introduction

This document contains **mixed content** including:
- ASCII text
- UTF-8 characters: café, naïve
- Emoji: 🎯 🎨 🎭
- Code blocks

## Code Example

```zig
const std = @import("std");

pub fn main() !void {
    std.debug.print("Hello, 世界!\n", .{});
}
```

## Data Table

| Column 1 | Column 2 | Column 3 |
|----------|----------|----------|
| α        | β        | γ        |
| 😀       | 😎       | 🤔       |
| 100%     | 50°C     | €99.99   |

## Special Characters

- Copyright: ©
- Registered: ®
- Trademark: ™
- Math: ∑ ∏ ∫ ∞
- Arrows: ← → ↑ ↓ ↔ ⇒
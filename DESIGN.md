# Design System — HamStation Pro

## Product Context
- **What this is:** Web-based amateur (ham) radio station logger with digital mode decoding, propagation tracking, contest support, and AI assistant
- **Who it's for:** Licensed amateur radio operators (hams) who want a modern, cross-platform station management tool
- **Space/industry:** Amateur radio software (peers: WSJT-X, N1MM+, Log4OM, QRZ.com)
- **Project type:** Data-dense web application (three-column layout, 17 sidebar sections)
- **Distribution:** Pure web app, web + bridge CLI, Electrobun desktop app

## Aesthetic Direction
- **Direction:** Industrial/Utilitarian — function-first, data-dense, monospace accents, muted palette
- **Decoration level:** Minimal — typography and color do the work. No gradients, no shadows beyond subtle elevation. Borders are 1px, colors are flat.
- **Mood:** A working tool that feels precise, fast, and trustworthy. Bloomberg Terminal meets amateur radio. Dense but not cluttered — every pixel earns its place.

## Typography
- **Display/Hero:** Geist (700) — clean geometric sans, designed for interfaces
- **Body:** Geist (400/500) — same family, unified visual language
- **UI/Labels:** Geist (500/600) — medium/semibold for labels and section headers
- **Data/Tables:** Geist Mono (400/500) — tabular-nums, designed to pair with Geist. Used for all radio data: frequencies, callsigns, RST, grids, times
- **Code:** Geist Mono (400)
- **Loading:** Google Fonts `https://fonts.googleapis.com/css2?family=Geist:wght@400;500;600;700&family=Geist+Mono:wght@400;500;600`
- **Scale:**
  - Display: 32px / -0.02em tracking
  - Heading: 20px / 600 weight
  - Body: 14px / 1.5 line-height
  - Caption: 12px
  - Data: 13px mono
  - Frequency: 18px mono / 600 weight
  - Label: 11px / uppercase / 0.05em tracking

## Color
- **Approach:** Restrained — one accent (orange) + neutrals + semantic. Color is rare and meaningful.
- **Primary:** `#FF6A00` — ham radio orange. Callsigns, active states, accent buttons, frequency display.
- **Primary dim:** `rgba(255, 106, 0, 0.12)` — active sidebar items, selected rows
- **Neutrals (dark):**
  - Background: `#0F1117` (cool blue-tinted dark, not true black)
  - Surface: `#161822`
  - Tertiary: `#1C1F2E`
  - Elevated: `#232738`
  - Border: `#2A2E3F`
  - Border subtle: `#1E2233`
- **Neutrals (light):**
  - Background: `#FAFAFA`
  - Surface: `#FFFFFF`
  - Tertiary: `#F5F5F7`
  - Border: `#E5E7EB`
- **Text (dark):** Primary `#F5F5F7`, Secondary `#A0A3B1`, Tertiary `#6B6F80`
- **Text (light):** Primary `#0A0A0F`, Secondary `#4B5563`, Tertiary `#9CA3AF`
- **Semantic:**
  - Green `#22C55E` — needed entities, new, success, connected
  - Yellow `#EAB308` — worked, warning, unsettled
  - Red `#EF4444` — error, TX active, storm
  - Blue `#3B82F6` — info, links
  - Gray `#6B7280` — confirmed, neutral
- **Night mode:** All colors swap to deep red spectrum for dark-adapted vision preservation
  - Accent: `#8B0000`
  - Background: `#0A0000`
  - Text: `#FF9999` / `#CC6666` / `#804040`
  - All semantic colors become `#8B0000`
- **Dark mode:** Default. The app lives in dark mode — most ham operating happens at night.

## Spacing
- **Base unit:** 4px
- **Density:** Compact — this is a data-dense tool, every pixel matters
- **Scale:** 2xs(2px) xs(4px) sm(8px) md(16px) lg(24px) xl(32px) 2xl(48px) 3xl(64px)
- **Table row padding:** 5px vertical, 8px horizontal
- **Sidebar item padding:** 6px 12px
- **Card padding:** 16px
- **Section gap:** 16px

## Layout
- **Approach:** Grid-disciplined — strict columns, predictable alignment
- **Grid:** Three-column: Sidebar (200-220px) | Content (fluid) | Inspector (280-300px)
- **Sidebar:** Collapsible, min 200px, max 280px
- **Inspector:** Toggleable, min 250px, max 400px
- **Max content width:** None (full width within column)
- **Border radius:** sm: 3px (badges), md: 4px (buttons, inputs), lg: 6px (cards), xl: 8px (panels)
- **Tables:** Primary UI pattern. Full-width, compact rows, sticky headers.

## Motion
- **Approach:** Minimal-functional — only transitions that aid comprehension
- **Easing:** enter: ease-out, exit: ease-in, move: ease-in-out
- **Duration:** micro: 50ms, short: 150ms, medium: 250ms
- **Panel open/close:** 150ms ease-out
- **Tab switches:** Instant (no animation)
- **No scroll animations, no page transitions, no hover transforms**

## Icon System
- **Library:** Lucide React (MIT, matches SF Symbols visual weight)
- **Size:** 16px for sidebar, 14px inline, 20px for section headers
- **Color:** Inherits text color, accent for active states

## Decisions Log
| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-03-23 | Initial design system | Industrial/utilitarian aesthetic for data-dense ham radio app. Geist + Geist Mono for modern cohesive look. Cool dark background (#0F1117) for depth. |
| 2026-03-23 | Electrobun over Electron | 14MB vs 200MB bundle, <50ms startup, system webview, Bun runtime. Better fit for data-dense app. |
| 2026-03-23 | Night mode as separate theme | Deep red (#8B0000) spectrum preserves dark-adapted vision for night operating. Not just "darker dark mode" — complete color system swap. |

# Design System Specification: The Empathetic Guardian

## 1. Overview & Creative North Star
**Creative North Star: "The Clinical Sanctuary"**
This design system rejects the cold, sterile grid of traditional medical software in favor of a "Clinical Sanctuary"—an environment that feels authoritative yet deeply comforting. We move beyond "standard" UI by employing an editorial layout strategy that prioritizes legibility for elderly users while maintaining a high-end, bespoke aesthetic. 

The "Empathetic Guardian" persona is realized through intentional asymmetry, massive typographic scales, and a "No-Line" philosophy. By removing rigid borders and replacing them with tonal layering, we create a digital experience that feels like a series of soft, physical surfaces rather than a complex technical interface.

---

## 2. Colors: The Trustworthy Spectrum
The palette shifts from functional green to a deep, resonant medical blue. This isn't just a color change; it is a shift toward a more "Architectural Blue" that implies stability and institutional trust.

### Primary & Secondary (The Foundation)
*   **Primary (`#004e9f`) & Primary Container (`#0066cc`):** Used for core actions and brand presence. These should be applied to large-scale elements to anchor the user’s eye.
*   **Secondary (`#4c616c`):** A muted slate blue that provides professional grounding without competing with the primary call-to-action.

### The "No-Line" Rule
**Explicit Instruction:** 1px solid borders are strictly prohibited for sectioning. 
Structure must be defined through:
1.  **Background Shifts:** Placing a `surface-container-low` section against a `surface` background.
2.  **Tonal Transitions:** Using subtle shifts in the surface-container tiers to denote hierarchy.

### Surface Hierarchy & Nesting
Treat the UI as stacked sheets of fine, heavy-weight paper.
*   **Base:** `surface` (#f7f9fc)
*   **Low Importance:** `surface-container-low` (#f2f4f7)
*   **Standard Container:** `surface-container` (#eceef1)
*   **Prominent Elements:** `surface-container-highest` (#e0e3e6)

### Signature Textures
*   **The Depth Gradient:** For hero sections or primary CTAs, use a subtle linear gradient from `primary` to `primary_container`. This adds a "soul" to the UI that flat hex codes lack.
*   **Glassmorphism:** For floating modals or navigation bars, use `surface` at 80% opacity with a `20px` backdrop-blur. This ensures the "Clinical Sanctuary" feels breathable and modern.

---

## 3. Typography: The Editorial Voice
We utilize **Lexend** across all tokens. Lexend was specifically designed to reduce visual stress and improve reading proficiency—crucial for our elderly demographic.

*   **Display Large (3.5rem):** Reserved for singular, high-impact data points (e.g., a heart rate or a "System OK" status).
*   **Headline Scale (1.5rem - 2rem):** Used for section headers. These should have generous leading (line-height) to ensure no "crowding" of text.
*   **Title Scale (1rem - 1.375rem):** The workhorse for card titles and navigation.
*   **Body Large (1rem):** This is our *minimum* for standard reading text to ensure accessibility without the user needing to zoom.

**Editorial Intent:** Use intentional white space. A headline should never be "tight" to the body text. Let the typography breathe to reduce cognitive load.

---

## 4. Elevation & Depth
In this system, depth is a tool for focus, not just decoration.

*   **The Layering Principle:** Achieve lift by nesting. A `surface-container-lowest` card (#ffffff) sitting on a `surface-container-low` background (#f2f4f7) creates a "soft lift" that is easier on aging eyes than high-contrast shadows.
*   **Ambient Shadows:** If an element must float (e.g., an emergency button), use a shadow color tinted with the `on-surface` token. 
    *   *Spec:* `0px 12px 32px rgba(25, 28, 30, 0.06)`. Large blur, ultra-low opacity.
*   **The "Ghost Border" Fallback:** If accessibility requirements demand a container boundary, use the `outline-variant` (#c1c6d5) at **15% opacity**. It should be felt, not seen.

---

## 5. Components

### Buttons
*   **Primary:** High-pill shape (`rounded-full`). Gradient of `primary` to `primary_container`. White text.
*   **Secondary:** `secondary_container` background with `on_secondary_container` text. No border.
*   **States:** On hover, increase the surface brightness by 5%. On press, scale the component down to 98% to provide tactile feedback.

### Cards & Lists
*   **The Divider Ban:** Strictly forbid `<hr>` or border-bottom lines. 
*   **Separation:** Separate list items using `8px` of vertical white space or by alternating background tones between `surface-container-low` and `surface-container`.

### Input Fields
*   **High-Contrast Focus:** Use `primary` for the active cursor and a `2px` "Ghost Border" that becomes 100% opaque `primary` only when focused. 
*   **Labeling:** Labels should use `title-sm` and never drop below `0.875rem` for legibility.

### Vital Monitoring Chips
*   **Monitoring (Yellow):** Use `tertiary_container` (#866300) for "caution" states.
*   **Emergency (Red):** Use `error` (#ba1a1a) with `on_error` (#ffffff) text. These components should use the `xl` (1.5rem) roundedness to stand out as "soft yet urgent" triggers.

---

## 6. Do's and Don'ts

### Do
*   **Do** use asymmetrical layouts. A large Headline-LG on the left with a smaller Body-LG on the right creates a sophisticated, editorial feel.
*   **Do** prioritize the "Surface-on-Surface" hierarchy over shadows.
*   **Do** use the `rounded-xl` and `rounded-full` tokens to maintain the "Empathetic" feel. Sharp corners feel dangerous; rounded corners feel safe.

### Don't
*   **Don't** use pure black (#000000) for text. Use `on_surface` (#191c1e) to reduce eye strain.
*   **Don't** use 1px dividers. If you feel the need for a line, use white space instead.
*   **Don't** use "Standard" blue. Always reference the specific `primary` (#004e9f) to ensure the medical-professional tone is maintained.
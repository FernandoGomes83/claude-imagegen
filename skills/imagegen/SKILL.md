---
name: imagegen
description: Generate images (photos, illustrations, mockups, textures, game assets, logos, hero images, social cards, quote cards) by delegating to the Codex CLI, which runs its built-in image_gen tool and saves a PNG to disk. Use whenever the user asks to generate, create, draw, or make an image, illustration, photo, mockup, banner, hero, cover, texture, sprite, or raster asset, and whenever another task needs a bitmap that does not exist yet. Do not use for editing existing SVG/vector assets, for diagrams that are better built in HTML/CSS/SVG, or when the user wants code instead of a bitmap.
---

# Image generation via Codex

Claude Code cannot generate images. This skill borrows the Codex CLI's built-in
`image_gen` tool, which runs on your ChatGPT account. **No `OPENAI_API_KEY`, no
per-image API billing.**

## Before generating: understand the request

**A generation costs 1-2 minutes. A vague prompt wastes them.** Detail is the single
biggest lever on quality here, so it is usually worth one round of questions to turn a
thin request into a rich one.

**Ask when a missing answer would visibly change the image:**

- **Purpose.** Where will it be used? (landing hero, Instagram post, game sprite, blog
  cover) This drives format, polish and framing more than anything else.
- **Style/medium.** Photo, flat illustration, 3D render, watercolor, editorial?
- **Text in the image.** Is there any? What are the *exact* words?
- **Format.** Square, landscape, portrait, a specific size?
- **Constraints.** Brand colors, things to avoid, no people, no text?

Use `AskUserQuestion` with **at most 2-3 questions**, each offering concrete options
(and a recommended one first). Then generate.

**Do NOT ask when:**

- The user already wrote a detailed prompt. Respect it, normalize it, don't interrogate.
- They're clearly exploring ("just show me something", "surprise me"). Generate and
  iterate from the result. A picture beats a questionnaire.
- The answer is obvious from context. You're building their landing page, so a hero for
  *that* page inherits *that* project's style and format.

When in doubt, ask **one** sharp question rather than three shallow ones. Or generate a
first pass and let the image itself drive the conversation.

## Usage

Always in the background. Each image takes **1-2 minutes**.

```bash
~/.claude/skills/imagegen/scripts/codex-image.sh \
  --prompt "minimalist ceramic mug hero, product photography, soft studio light" \
  --out /absolute/path/hero.png
```

The script prints **only the absolute path** to stdout. Then `Read` that path to actually
look at the image and check it against the request before handing it over.

For long or multi-line prompts, use `--prompt-file` instead of fighting shell quoting:

```bash
~/.claude/skills/imagegen/scripts/codex-image.sh -f prompt.md -o hero.png
```

If the file has ```` ``` ```` fences, the **first** block is used as the prompt (so a
prompt file can keep notes, alternatives, or a human-readable variant alongside it).
No fence: the whole file. Accepts `-` for stdin.

Other options: `--ref <file>` (reference image, repeatable), `--model`, `--log`,
`--keep-log`. Without `--out`, saves to `./<slug>-<timestamp>.png`.

## Rules

- **Run in the background** (`run_in_background: true`). Never in the foreground.
- **One image per call.** For several, fire calls in parallel. Don't ask for multiple
  images in a single prompt.
- **Always `Read` the generated file** before saying it's done. The script guarantees the
  file exists and is a raster; only the Read guarantees the image is *right*.
- **Show the user the result** and offer one targeted next step, rather than declaring
  victory.
- **No overwriting**: if `--out` exists, the script fails on purpose. Use a new name
  (`hero-v2.png`) to iterate.
- On failure the script keeps the log and points to it on stderr. Read the log before
  retrying.

## Writing the prompt

The underlying model (`gpt-image-2`) is **very capable**: it handles long detailed specs,
renders legible text inside the image, respects format and composition, and follows
negative constraints. **Don't skimp on the prompt.** A vague prompt yields a generic
image. The waste is asking for too little, not too much.

A user prompt that is already detailed should be **preserved and normalized**, never
summarized nor inflated with creativity nobody asked for.

### What to include

- **Intended use** ("landing page hero", "game sprite", "ebook cover"). Sets polish,
  framing and format.
- **Style/medium** ("product photography", "flat illustration", "stylized 3D render",
  "watercolor", "35mm editorial photo").
- **Subject and scene**, concretely: materials, textures, surfaces, environment.
- **Composition/framing** ("wide, negative space on the left for a headline",
  "top-down close-up", "rule of thirds").
- **Light and mood** ("soft studio light", "golden hour", "night neon").
- **Palette** ("deep amber, coral, muted blue").
- **Constraints/negatives** ("no text, no logo, no watermark, no people").

### Format and aspect ratio

Ask for it in the prompt. **It works.** Observed: a request framed as "product photo"
came back 1536×1024 landscape on its own, while illustrations with no format specified
came back square. A prompt asking for "3:4 (1080x1350)" returned exactly 1080×1350.

Say "landscape 16:9", "portrait 2:3", "square", "4K landscape". Sizes `gpt-image-2`
handles well: `1024x1024`, `1536x1024`, `1024x1536`, `2048x2048`, `2048x1152`,
`3840x2160` (4K landscape), `2160x3840` (4K portrait).

It is not a pixel-exact contract. **Confirm the dimensions in the Read** if they matter.

### Text inside the image

The model renders real text, **including accented Latin scripts**. Verified in Brazilian
Portuguese: "A graça de Deus não é mérito — é presença, perdão e compaixão." came back
with every cedilla, tilde and acute accent correct, em dash included, first try. A
handwritten-notebook layout with 8 separate strings, dotted leaders and thousand
separators (`US$ 1.337`) also came back clean. Don't dumb down copy out of fear.

Still, be precise:

- Quote it **verbatim**: `Text (verbatim): "Café da Manhã"`.
- Specify **typography and placement** ("elegant serif, centered, 3 lines").
- For accented or non-English text, reinforce it in the constraints ("render all
  accents exactly as written") and call out specific cases.
- **Spell out** proper nouns, brands, or invented words letter by letter.
- **Always check the text in the Read.** Text is the most fragile part and the easiest
  to miss. The longer the copy, the higher the risk.

### Optional schema

For complex requests, the labeled schema the underlying skill already uses works well:

```text
Use case: <slug>          # photorealistic-natural, product-mockup, ui-mockup,
                          # infographic-diagram, ads-marketing, logo-brand,
                          # illustration-story, stylized-concept, historical-scene...
Asset type: <where it will be used>
Primary request: <the main ask>
Scene/backdrop: <environment>
Subject: <subject>
Style/medium: <photo/illustration/3D>
Composition/framing: <framing and format>
Lighting/mood: <light and mood>
Color palette: <palette>
Materials/textures: <surfaces>
Text (verbatim): "<exact text>"
Constraints: <keep/avoid>
```

Full taxonomy and more recipes live in the Codex skill itself:
`~/.codex/skills/.system/imagegen/SKILL.md` and `references/sample-prompts.md`.

## Iterating

Change **one thing at a time** and write to a new file. To vary on a previous result,
pass it with `--ref` and describe only the difference.

## Known limits

- **Transparent background** is not direct: the built-in tool exposes no alpha. The path
  is to generate on a flat chroma-key (`#00ff00`) and remove it with
  `~/.codex/skills/.system/imagegen/scripts/remove_chroma_key.py`. True native
  transparency would need the fallback CLI with `OPENAI_API_KEY`. Ask first.
- **Editing a local image** through the built-in tool is limited. `--ref` is for
  reference; pixel-faithful editing wants the fallback CLI.
- **Aspect ratio** is honored when asked for, but is **not a pixel-exact guarantee**:
  there is no size flag on the built-in tool. If the dimension is a hard requirement
  (e.g. an OG image at 1200×630), verify in the Read and resize afterwards.

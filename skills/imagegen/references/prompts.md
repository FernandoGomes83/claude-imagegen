# Prompts: schema, recipes and evidence

## Labeled schema for complex requests

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

## Recipe: visual references for a landing page

Use it when the user wants to see the whole page before building it.

- One horizontal image **per section**. A page with 8 sections gets 8 images; never squeeze
  several sections into one image.
- One palette and one type direction for all of them, written the same way in every prompt.
- Vary the composition from section to section (not always text on the left and image on the
  right) and vary the scale of the hero.
- Fire the calls in parallel, one image each, and name the files in page order
  (`01-hero.png`, `02-proof.png`).
- They are references to build from, not assets to ship. Say so when you hand them over.

## Evidence

- Text: "A graça de Deus não é mérito — é presença, perdão e compaixão." came back with every
  cedilla, tilde and acute accent correct, em dash included, first try. A handwritten-notebook
  layout with 8 separate strings, dotted leaders and thousand separators (`US$ 1.337`) also
  came back clean.
- Reference: a fox illustration used as reference produced an owl with the same background, palette, circular composition and grain. A portrait photo used as reference produced the same recognizable person in a new scene.

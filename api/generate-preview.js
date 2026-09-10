// Vercel serverless function: /api/generate-preview
// OPENAI_API_KEY must exist in Vercel Environment Variables.
// The browser never receives the API key.

const MAX_BODY_CHARS = 3_800_000;

function dataUrlToBlob(dataUrl) {
  if (typeof dataUrl !== "string" || !dataUrl.startsWith("data:image/")) {
    throw new Error("Invalid image data.");
  }
  const comma = dataUrl.indexOf(",");
  const meta = dataUrl.slice(5, comma);
  const base64 = dataUrl.slice(comma + 1);
  const mime = meta.split(";")[0] || "image/png";
  const bytes = Buffer.from(base64, "base64");
  return new Blob([bytes], { type: mime });
}

export default async function handler(req, res) {
  if (req.method !== "POST") {
    res.setHeader("Allow", "POST");
    return res.status(405).json({ error: "POST only." });
  }

  if (!process.env.OPENAI_API_KEY) {
    return res.status(500).json({ error: "OPENAI_API_KEY is not configured in Vercel." });
  }

  try {
    const rawSize = JSON.stringify(req.body || {}).length;
    if (rawSize > MAX_BODY_CHARS) {
      return res.status(413).json({ error: "Preview request is too large." });
    }

    const {
      baseImageDataUrl,
      artworkDataUrl,
      shirtColor = "black",
      line1 = "",
      line2 = "",
      font = "Arial",
      accent = "#22b8ff",
      symbol = ""
    } = req.body || {};

    if (!baseImageDataUrl || !artworkDataUrl) {
      return res.status(400).json({ error: "Missing preview images." });
    }

    const form = new FormData();
    form.append("model", "gpt-image-2.5-sunburst");
    form.append("quality", "low");
    form.append("size", "1024x1536");

    // First image = model/shirt reference. Second image = exact artwork reference.
    form.append("image", dataUrlToBlob(baseImageDataUrl), "model-reference.png");
    form.append("image", dataUrlToBlob(artworkDataUrl), "exact-artwork.png");

    form.append(
      "prompt",
      `Create a photorealistic ecommerce lifestyle preview using image 1 as the person/garment reference and image 2 as the exact shirt artwork.

PRESERVE from image 1: the same person, face, body, pose, camera angle, crop, hairstyle, lighting, background, garment shape, fabric texture, folds and ${shirtColor} shirt color.

EDIT ONLY the visible front print area of the T-shirt. Place the artwork from image 2 naturally on the upper-center chest as if professionally DTG printed into the fabric. Make the print follow the garment's perspective, folds, highlights and shadows.

The artwork must remain faithful to image 2. It contains the brand wording "Not AI, Just I.", customer lines "${String(line1).slice(0,40)}" and "${String(line2).slice(0,40)}", font family ${String(font).slice(0,40)}, accent ${String(accent).slice(0,20)}, and symbol ${String(symbol).slice(0,8)}. Do not invent extra logos, text, decorations, labels or graphics. Do not change the person's identity or the garment itself.

This is a visualization, so prioritize photorealistic fabric integration while preserving the supplied artwork as closely as possible.`
    );

    const openai = await fetch("https://api.openai.com/v1/images/edits", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${process.env.OPENAI_API_KEY}`
      },
      body: form
    });

    const data = await openai.json();

    if (!openai.ok) {
      console.error("OpenAI image error:", data);
      const msg = data?.error?.message || "OpenAI image generation failed.";
      return res.status(openai.status >= 500 ? 502 : openai.status).json({ error: msg });
    }

    const b64 = data?.data?.[0]?.b64_json;
    const url = data?.data?.[0]?.url;

    if (b64) {
      return res.status(200).json({ image: `data:image/png;base64,${b64}` });
    }
    if (url) {
      return res.status(200).json({ image: url });
    }

    return res.status(502).json({ error: "OpenAI returned no image." });
  } catch (error) {
    console.error(error);
    return res.status(500).json({ error: error?.message || "Unexpected preview error." });
  }
}

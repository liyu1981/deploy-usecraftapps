// Cloudflare Pages bootstrap: reassemble WASM files that were split into
// <= 20 MB chunks at build time. Intercepts fetch() for `*_bg.wasm` and
// returns a single Response whose body is the stitched bytes.
(function () {
  const originalFetch = window.fetch.bind(window);

  function toUrl(input) {
    if (input instanceof Request) return new URL(input.url);
    if (input instanceof URL) return new URL(input.href);
    return new URL(String(input), document.baseURI);
  }

  window.fetch = async function (input, init) {
    let url;
    try {
      url = toUrl(input);
    } catch (e) {
      return originalFetch(input, init);
    }

    if (!url.pathname.endsWith("_bg.wasm")) {
      return originalFetch(input, init);
    }

    const manifestUrl = new URL(url.pathname + ".manifest", url);
    let manifestResponse;
    try {
      manifestResponse = await originalFetch(manifestUrl, { cache: "no-store" });
    } catch (e) {
      manifestResponse = null;
    }

    if (!manifestResponse || !manifestResponse.ok) {
      // Unsplit WASM (or missing manifest): pass through unchanged.
      return originalFetch(input, init);
    }

    const manifestText = await manifestResponse.text();
    const chunkNames = manifestText
      .split(/\s+/)
      .map((s) => s.trim())
      .filter(Boolean);

    if (chunkNames.length === 0) {
      return originalFetch(input, init);
    }

    // Sequential fetch keeps peak memory lower than Promise.all.
    const buffers = [];
    for (const name of chunkNames) {
      const chunkUrl = new URL(name, manifestUrl);
      const response = await originalFetch(chunkUrl);
      if (!response.ok) {
        throw new Error(
          "Failed to fetch WASM chunk: " + chunkUrl.href + " (" + response.status + ")"
        );
      }
      buffers.push(await response.arrayBuffer());
    }

    const totalLength = buffers.reduce((acc, buf) => acc + buf.byteLength, 0);
    const combined = new Uint8Array(totalLength);
    let offset = 0;
    for (const buf of buffers) {
      combined.set(new Uint8Array(buf), offset);
      offset += buf.byteLength;
    }

    return new Response(combined.buffer, {
      status: 200,
      statusText: "OK",
      headers: {
        "Content-Type": "application/wasm",
        "Content-Length": String(totalLength),
      },
    });
  };
})();

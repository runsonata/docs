# @sonata/image

Load, edit and save images: resizing, cropping, color and tone, filters, drawing shapes and
text, compositing, analysis and animated GIFs. Backed by ImageMagick (version 6 or 7).

```luau
local image = require("@sonata/image")

image.load("photo.jpg")
    :autoOrient()
    :resize(800) -- 800 wide; the height keeps the aspect ratio
    :drawText("© me", 10, 10, { gravity = "bottom-right", size = 18, color = "white" })
    :save("photo.webp", { quality = 85 })
```

!!! note "Availability"

    `image` is compiled in only when ImageMagick's development files (MagickWand) were found
    when Sonata was built; see [Installation](../../guide/installation.md#requirements). A build
    without them leaves the library out, and `require("@sonata/image")` fails with
    `unknown built-in library`. Check with `pcall(require, "@sonata/image")`.

    ImageMagick is linked as a shared library, so a program built with `sn build` needs it
    installed on the machine it runs on, and can't be built with
    [`--standalone`](../../guide/building.md#standalone-programs).

**Errors:** everything raises, with the function's name first
(`"Image:resize: give a width, a height, or both"`). Options tables reject names they don't
know, so typos don't go unnoticed.

## Conventions

- **Methods change the image in place and return it**, so they chain. Use
  [`img:clone()`](#imgclone) to keep the original.
- **Every frame.** An image can hold several frames (an animated GIF, a multi-page TIFF).
  Editing methods apply to every frame. Fields, pixel access and analysis look at the first
  frame.
- **Coordinates** are in pixels and start at 0 in the top-left corner.
- **Sizes** (widths, heights) are whole numbers from 1 to 1048576.
- **Fractions.** Fuzz, thresholds, levels, opacity and amounts are fractions from 0 to 1, not
  ImageMagick's percentages or quantum values.
- **Names** of filters (`"lanczos"`), blend modes (`"multiply"`), colorspaces, noise types and
  so on are ImageMagick's. Case, `-`, `_` and spaces don't matter, so `"linear-dodge"` finds
  `LinearDodge`. [`image.options(kind)`](#imageoptions) lists them.
- **Blocking.** Every call runs to completion before it returns: a long operation (decoding a
  huge file, a large blur) holds up the other tasks while it runs.

### Colors

```luau
type ColorInput = string | { r: number, g: number, b: number, a: number? }
type Color = { r: number, g: number, b: number, a: number }
```

A color argument is any color string ImageMagick knows (`"red"`, `"#ff000080"`,
`"rgba(255,0,0,0.5)"`, `"none"` for transparent) or a table with channels from 0 to 255 (`a`
defaults to 255, opaque). Colors that come back are always `Color` tables with every channel
from 0 to 255.

### Gravity

```luau
type Gravity = "top-left" | "top" | "top-right" | "left" | "center" | "right"
    | "bottom-left" | "bottom" | "bottom-right"
```

Where something goes inside a larger area. ImageMagick's compass names (`"northwest"`,
`"south"`, ...) work too. With a gravity, `x` and `y` offsets point inward from the edge it
sticks to: `{ gravity = "bottom-right", x = 10, y = 10 }` is 10 pixels from the right and
bottom edges.

## Creating images

### image.load

```luau
image.load(path: string, options: ReadOptions?): Image
```

Reads an image file. Animated and multi-page files keep every frame.

```luau
type ReadOptions = {
    format: string?,  -- for data without a recognizable signature ("tga", "rgba", ...)
    density: number?, -- pixels per inch for vector formats (SVG, PDF); higher is sharper
    frame: number?,   -- only keep this frame (1-based)
    define: { [string]: string | number | boolean }?, -- ImageMagick coder options
}
```

The format is found from the file's contents, or from its extension for formats without a
signature. The path is only ever a path: ImageMagick's `file.gif[0]` and `png:file` syntaxes
aren't interpreted. `define` passes coder options, such as `{ ["jpeg:size"] = "400x400" }`
(decode a JPEG at a reduced size, which is much faster for thumbnails).

```luau
local first = image.load("animation.gif", { frame = 1 })
local logo = image.load("logo.svg", { density = 300 })
```

### image.decode

```luau
image.decode(data: string | buffer, options: ReadOptions?): Image
```

Reads an image from its bytes, as [`image.load`](#imageload) reads a file.

### image.info

```luau
image.info(source: string | buffer): Info
```

The size, format and frame count, without decoding the pixels. A string is a path; a buffer
holds the image's bytes.

```luau
type Info = { width: number, height: number, format: string, frames: number }
```

```luau
print(image.info("photo.jpg").width) --> 4032
```

### image.new

```luau
image.new(width: number, height: number, background: ColorInput?): Image
```

A blank canvas, transparent unless `background` is given.

### image.generate

```luau
image.generate(spec: string, width: number?, height: number?): Image
```

An image ImageMagick makes from a description. Gradients and patterns need a size.

| Spec | Makes |
|---|---|
| `"xc:<color>"`, `"canvas:<color>"` | A solid color. |
| `"gradient:<from>-<to>"` | A linear gradient, top to bottom. |
| `"radial-gradient:<from>-<to>"` | A radial gradient. |
| `"plasma:"` | Random plasma fractal. |
| `"pattern:<name>"` | A built-in pattern (`checkerboard`, `bricks`, `hexagons`, ...). |
| `"label:<text>"` | Text on a canvas that fits it. |
| `"caption:<text>"` | Text wrapped to the given width. |
| `"hald:<level>"` | An identity Hald CLUT. |
| `"rose:"`, `"logo:"`, `"wizard:"`, `"granite:"`, `"netscape:"` | ImageMagick's built-in images. |

Other ImageMagick pseudo-formats, which would read files or URLs, are refused. A `label:` or
`caption:` text starting with `@` is drawn as is, never read from a file.

```luau
local sky = image.generate("gradient:skyblue-white", 640, 360)
```

### image.fromPixels

```luau
image.fromPixels(width: number, height: number, data: buffer | string, channels: string?): Image
```

An image from raw 8-bit samples, row by row, top to bottom. `channels` is the layout of each
pixel: letters from `"rgbacmyk"` (`"rgba"` by default, `"rgb"`, `"bgra"`, ...), or `"gray"` or
`"graya"`. `data` must have exactly `width * height * #channels` bytes. The reverse of
[`img:pixels`](#imgpixels).

### image.text

```luau
image.text(text: string, style: (TextStyle & { padding: number? })?): Image
```

Text on a canvas that just fits it. The [`TextStyle`](#textstyle) is the text's, except that
`background` is the canvas color (default transparent) and `padding` adds that many pixels on
every side.

```luau
local badge = image.text("v1.0.2", { size = 32, color = "white", background = "#5e35b1", padding = 8 })
```

### image.animate

```luau
image.animate(frames: { Image }, options: { delay: number?, loop: number? }?): Image
```

One animation made of every frame of `frames`, in order. `delay` is the time each frame is
shown, in milliseconds; `loop` is how many times it plays (default 0: forever). See
[Animation](#animation).

### image.append

```luau
image.append(images: { Image }, options: AppendOptions?): Image
```

The first frames of `images`, side by side, or stacked with `vertical`.

```luau
type AppendOptions = {
    vertical: boolean?,             -- stack top to bottom (default: left to right)
    gap: number?,                   -- pixels between images (default 0)
    background: ColorInput?,        -- for the gaps and uneven edges (default transparent)
    align: ("start" | "center" | "end")?, -- across the row or column (default "start")
}
```

### image.grid

```luau
image.grid(images: { Image }, options: GridOptions?): Image
```

A contact sheet: the first frames of `images` in a grid of equal cells, row by row, each
centered in its cell. Images bigger than a cell shrink to fit it.

```luau
type GridOptions = {
    columns: number?,        -- default: a square-ish grid
    gap: number?,            -- pixels between cells (default 0)
    background: ColorInput?, -- default transparent
    cellWidth: number?,      -- default: the widest image
    cellHeight: number?,     -- default: the tallest image
}
```

## Image

An image is a value of type `Image` (`typeof(img) == "Image"`). `tostring(img)` gives
`"Image(640x480 PNG)"` (with `, 12 frames` for an animation), or `"Image(closed)"` after [`img:close()`](#imgclose).

### Fields

Read-only, and describing the first frame.

| Field | Type | Description |
|---|---|---|
| `width` | `number` | Width in pixels. |
| `height` | `number` | Height in pixels. |
| `format` | `string?` | The format it was read from (`"png"`, `"jpeg"`, ...); `nil` for new images. |
| `frames` | `number` | Number of frames: 1 unless animated or multi-page. |
| `depth` | `number` | Bits per channel. |
| `colorspace` | `string` | `"sRGB"`, `"Gray"`, `"CMYK"`, ... |
| `hasAlpha` | `boolean` | Whether it has an alpha channel. |

### Saving and encoding

#### img:save

```luau
img:save(path: string, options: SaveOptions?): Image
```

Writes the image to `path`, replacing the file. The format is `options.format`, else the
path's extension, else the image's own format. Returns the image.

```luau
type EncodeOptions = {
    quality: number?,      -- 1 to 100, for lossy formats (JPEG, WebP, AVIF, ...); PNG's compression level
    lossless: boolean?,    -- lossless WebP, JPEG XL or HEIC
    progressive: boolean?, -- progressive JPEG, interlaced PNG or GIF
    strip: boolean?,       -- leave out metadata (EXIF, ICC profiles, comments)
    background: ColorInput?, -- what transparent pixels become in JPEG, BMP and PPM (default white)
    define: { [string]: string | number | boolean }?, -- ImageMagick coder options
}

type SaveOptions = EncodeOptions & { format: string? }
```

Formats without transparency (JPEG, BMP, PPM/PGM/PNM) get the image drawn on `background`,
instead of whatever color the transparent pixels happen to hold. The image itself isn't
changed. An animation saved as GIF, WebP or another animated format keeps every frame.

```luau
img:save("out.jpg", { quality = 80, progressive = true, strip = true })
img:save("out", { format = "png", define = { ["png:compression-level"] = 9 } })
```

#### img:encode

```luau
img:encode(format: string?, options: EncodeOptions?): string
```

The image's bytes in `format` (default: its own format, or PNG for new images), as
[`img:save`](#imgsave) would write them.

```luau
local png = img:encode("png")
```

#### img:clone

```luau
img:clone(): Image
```

An independent copy. It is cheap: the two share their pixels until one of them changes.

#### img:close

```luau
img:close(): ()
```

Frees the pixels now instead of at garbage collection. Using the image afterwards raises;
closing twice is fine.

The garbage collector only sees a small handle, not the pixels ImageMagick holds, so it may let
many large images pile up before it collects them. Close the images you are done with in loops
that load many files.

### Pixels and metadata

#### img:pixels

```luau
img:pixels(options: PixelsOptions?): buffer
```

Raw 8-bit samples of the first frame, row by row, top to bottom.

```luau
type PixelsOptions = {
    channels: string?, -- "rgba" by default; as in image.fromPixels
    x: number?, y: number?, width: number?, height: number?, -- a region (default: the whole image)
}
```

```luau
local data = img:pixels({ channels = "gray" })
print(buffer.readu8(data, 0)) -- the top-left pixel's brightness, 0 to 255
```

#### img:getPixel

```luau
img:getPixel(x: number, y: number): Color
```

The first frame's pixel at (x, y). Raises if it is outside the image.

#### img:setPixel

```luau
img:setPixel(x: number, y: number, color: ColorInput): Image
```

Sets the pixel at (x, y) in every frame. A transparent color adds an alpha channel if the
image has none.

#### img:frame

```luau
img:frame(index: number): Image
```

A copy of frame `index` (1-based) as a single-frame image.

#### img:metadata

```luau
img:metadata(pattern: string?): { [string]: string }
```

EXIF and the other properties of the first frame, optionally only those matching a pattern
such as `"exif:*"`.

```luau
local exif = img:metadata("exif:*")
print(exif["exif:Model"], exif["exif:DateTimeOriginal"])
```

#### img:setMetadata

```luau
img:setMetadata(name: string, value: string?): Image
```

Sets a property such as `"comment"`; `nil` removes it.

#### img:strip

```luau
img:strip(): Image
```

Removes EXIF, ICC profiles and comments.

#### img:signature

```luau
img:signature(): string
```

A SHA-256 (hex) of the first frame's pixels. Images with the same pixels have the same
signature, whatever the file format, bit depth or metadata they came from.

#### img:resolution / img:setResolution

```luau
img:resolution(): (number, number)
img:setResolution(x: number, y: number?): Image
```

The horizontal and vertical resolution, in pixels per inch. `y` defaults to `x`. The pixels
don't change; it is a note in the file, used for printing and by some viewers.

### Geometry

#### img:resize

```luau
img:resize(width: number?, height: number?, options: ResizeOptions?): Image
```

Resizes every frame. With one size, the other keeps the aspect ratio:
`img:resize(800)`, `img:resize(nil, 600)`. With both, `fit` decides.

```luau
type ResizeOptions = {
    fit: ("fill" | "contain" | "cover")?, -- with both sizes (default "fill")
    filter: string?,   -- resampling filter: "lanczos", "mitchell", "point", ... (image.options("filter"))
    gravity: Gravity?, -- with fit = "cover": which part to keep (default "center")
    enlarge: boolean?, -- false never makes the image bigger (default true)
}
```

| `fit` | Result |
|---|---|
| `"fill"` | Exactly width × height, stretched if the aspect ratio differs. |
| `"contain"` | As big as fits inside width × height, keeping the aspect ratio. |
| `"cover"` | Fills width × height, keeping the aspect ratio, then crops what sticks out. |

```luau
img:clone():resize(256, 256, { fit = "cover" }):save("avatar.png")      -- square, cropped
img:clone():resize(1920, 1080, { fit = "contain", enlarge = false })    -- at most 1920x1080
```

#### img:thumbnail

```luau
img:thumbnail(width: number?, height: number?, options: ResizeOptions?): Image
```

Like [`img:resize`](#imgresize), tuned for previews: faster, removes metadata, and by default
fits inside the box (`fit = "contain"`) and never enlarges (`enlarge = false`).

#### Other geometry methods

| Method | Description |
|---|---|
| `img:scale(factor, factorY?)` | Resizes by a factor: 0.5 halves, 2 doubles. `factorY` defaults to `factor`. |
| `img:crop(x, y, width, height)` | Keeps that rectangle. Parts of it outside the image are left out; raises if all of it is. |
| `img:extent(width, height, options?)` | Pads (or crops) to exactly width × height. `options.gravity` places the image (default `"center"`); `options.background` fills the rest (default transparent). |
| `img:trim(fuzz?)` | Cuts away borders that have the corner's color (within `fuzz`). |
| `img:rotate(degrees, background?)` | Rotates clockwise. The uncovered corners get `background` (default transparent). |
| `img:flip()` | Upside down. |
| `img:mirror()` | Left to right. |
| `img:transpose()` | Mirrors along the top-left to bottom-right diagonal. |
| `img:transverse()` | Mirrors along the top-right to bottom-left diagonal. |
| `img:autoOrient()` | Rotates the way the camera's EXIF orientation says, then resets it. Do this first with photos. |
| `img:shear(x, y?, background?)` | Shears by `x` and `y` degrees (each between -89.9 and 89.9). |
| `img:roll(x, y)` | Shifts the pixels, wrapping around the edges. |
| `img:border(size, color?)` | Adds `size` pixels of `color` (default black) on every side. |
| `img:distort(method, arguments, options?)` | One of ImageMagick's distortions, with its numeric arguments (see below). |
| `img:liquidRescale(width, height)` | Content-aware resize (seam carving). Needs an ImageMagick built with liblqr, which some (Homebrew's) aren't; raises otherwise. |
| `img:deskew(threshold?)` | Straightens a scanned page. `threshold` defaults to 0.4. |

`img:distort` takes ImageMagick's method names (`"perspective"`, `"arc"`, `"barrel"`,
`"polar"`, `"srt"`, ...; [`image.options("distort")`](#imageoptions)) and their arguments as an
array of numbers. `options.bestFit` grows the image to hold the whole result, and
`options.background` colors the uncovered area (default transparent).

```luau
img:distort("srt", { 0.5, 30 }) -- scale by 0.5 and rotate 30 degrees around the center
img:distort("arc", { 120 }, { bestFit = true })
```

### Color and tone

| Method | Description |
|---|---|
| `img:grayscale()` | Shades of gray. |
| `img:negate()` | Inverts the colors. |
| `img:sepia(threshold?)` | Sepia tone. `threshold` defaults to 0.8. |
| `img:brightnessContrast(brightness, contrast?)` | Each from -100 to 100; 0 leaves it unchanged. |
| `img:modulate(brightness?, saturation?, hue?)` | Percentages: 100 leaves a property unchanged, saturation 0 is gray, and hue (0 to 200) rotates the colors, halfway around the color wheel at 0 or 200. |
| `img:gamma(value)` | Above 1 brightens, below 1 darkens. |
| `img:level(black?, white?, gamma?)` | `black` and `white` (defaults 0 and 1) become the new darkest and brightest values. |
| `img:normalize()` | Stretches the values to use the full range. |
| `img:equalize()` | Histogram equalization. |
| `img:autoLevel()` | Like `level`, with black and white taken from the image. |
| `img:autoGamma()` | Picks a gamma that brings the mean to the middle. |
| `img:contrast(strength?, midpoint?)` | Sigmoidal contrast: positive `strength` adds contrast, negative removes it (default 3); `midpoint` defaults to 0.5. |
| `img:colorize(color, amount?)` | Blends every pixel toward `color` by `amount` (default 0.5). |
| `img:tint(color, amount?)` | Tints the midtones toward `color` (`amount` default 0.5). |
| `img:threshold(value?)` | Pixels brighter than `value` (default 0.5) become white, the rest black. |
| `img:posterize(levels, dither?)` | `levels` values per channel (2 to 256). |
| `img:quantize(colors, options?)` | At most `colors` colors. `options.dither` (default `true`), `options.colorspace` to choose them in. |
| `img:monochrome()` | Pure black and white, dithered. |
| `img:solarize(threshold?)` | Inverts the pixels brighter than `threshold` (default 0.5). |
| `img:replaceColor(from, to, fuzz?)` | Replaces `from`, and colors within `fuzz` of it, with `to`. |
| `img:transparent(color, fuzz?)` | Makes `color`, and colors within `fuzz`, transparent. |
| `img:floodFill(x, y, color, fuzz?)` | Paint bucket at (x, y). |
| `img:alpha(mode)` | The alpha channel: `"on"`, `"off"`, `"remove"` (onto the background color), `"opaque"`, `"transparent"`, `"extract"`, ... ([`image.options("alpha")`](#imageoptions)). |
| `img:opacity(amount)` | Multiplies every pixel's alpha by `amount`. |
| `img:flatten(background?)` | Merges every frame onto `background` (default white), removing transparency. The result has one frame. |
| `img:toColorspace(name)` | Converts to `"gray"`, `"cmyk"`, `"lab"`, `"hsl"`, `"srgb"`, ... ([`image.options("colorspace")`](#imageoptions)). |
| `img:channel(name)` | Keeps one channel (`"red"`, `"alpha"`, ...) as a grayscale image. |
| `img:fx(expression)` | Runs an ImageMagick [FX expression](https://imagemagick.org/script/fx.php) for every pixel, such as `"u*0.5"`. |

`fuzz` is how far a color may be from the given one and still count as the same: 0 (the
default) is an exact match, 1 matches everything.

```luau
-- A white background becomes transparent, then the image is cut to its content.
img:transparent("white", 0.05):trim()
```

### Filters and effects

Unless noted, `sigma` is the strength and `radius` the size of the area looked at, in pixels;
a `radius` of 0 (the default) lets ImageMagick pick one from `sigma`.

| Method | Description |
|---|---|
| `img:blur(sigma?, radius?)` | Gaussian blur. `sigma` defaults to 2. |
| `img:sharpen(sigma?, radius?)` | `sigma` defaults to 1. |
| `img:unsharp(sigma?, amount?, threshold?, radius?)` | Unsharp mask, the photographer's sharpen. Defaults: `sigma` 1, `amount` 1, `threshold` 0.05. |
| `img:motionBlur(sigma?, angle?, radius?)` | Blur along `angle` degrees (default 0). `sigma` defaults to 5. |
| `img:rotationalBlur(angle?)` | Blur around the center, by `angle` degrees (default 10). |
| `img:noise(type?, amount?)` | Adds noise: `"gaussian"` (default), `"impulse"`, `"poisson"`, `"uniform"`, ... ([`image.options("noise")`](#imageoptions)). `amount` defaults to 1. |
| `img:despeckle()` | Reduces speckle noise. |
| `img:median(size?)` | Removes noise while keeping edges. `size` in pixels, default 3. |
| `img:charcoal(sigma?, radius?)` | A charcoal drawing. |
| `img:sketch(sigma?, angle?, radius?)` | A pencil sketch, strokes at `angle` degrees (default 45). |
| `img:oilPaint(radius?)` | An oil painting. `radius` defaults to 3. |
| `img:emboss(sigma?, radius?)` | A relief. |
| `img:edge(radius?)` | Highlights edges. `radius` defaults to 1. |
| `img:swirl(degrees?)` | Swirls around the center (default 90). |
| `img:implode(amount?)` | Positive pulls toward the center, negative pushes out (default 0.5). |
| `img:wave(amplitude?, wavelength?)` | A sine wave (defaults 10 and 100). The image grows by `2 * amplitude` vertically. |
| `img:spread(radius?)` | Scatters pixels randomly (default 3). |
| `img:vignette(sigma?, color?, x?, y?)` | Fades the edges to `color` (default black); `x` and `y` inset the ellipse. |
| `img:pixelate(size?)` | Blocks of size × size pixels (default 8). |
| `img:morphology(method, kernel, iterations?)` | A morphology operation (`"dilate"`, `"erode"`, `"open"`, `"close"`, `"edge"`, ...; [`image.options("morphology")`](#imageoptions)) with a kernel such as `"disk:3"`. `iterations` defaults to 1; -1 repeats until nothing changes. |
| `img:convolve(kernel)` | Convolves with a kernel: a square array of numbers, row by row, or ImageMagick kernel text. |

```luau
img:convolve({ 0, -1, 0, -1, 5, -1, 0, -1, 0 }) -- the same as "3x3: 0,-1,0 -1,5,-1 0,-1,0"
```

### Compositing and drawing

#### img:composite

```luau
img:composite(other: Image, options: CompositeOptions?): Image
```

Draws the first frame of `other` on top of every frame.

```luau
type CompositeOptions = {
    x: number?, y: number?, -- offset in pixels, from the gravity's edge (default 0)
    gravity: Gravity?,      -- default "top-left"
    blend: string?,         -- how the pixels mix: "over" (default), "multiply", "screen", "overlay", ...
    opacity: number?,       -- 0 to 1 (default 1)
}
```

`blend` takes any of ImageMagick's compose operators
([`image.options("compose")`](#imageoptions)).

```luau
local watermark = image.load("logo.png"):resize(120)
photo:composite(watermark, { gravity = "bottom-right", x = 16, y = 16, opacity = 0.6 })
```

#### Shapes

```luau
img:drawRect(x: number, y: number, width: number, height: number, style: ShapeStyle?): Image
img:drawCircle(x: number, y: number, radius: number, style: ShapeStyle?): Image
img:drawEllipse(x: number, y: number, radiusX: number, radiusY: number, style: ShapeStyle?): Image
img:drawLine(x1: number, y1: number, x2: number, y2: number, style: ShapeStyle?): Image
img:drawPolygon(points: { Point }, style: ShapeStyle?): Image
img:drawPolyline(points: { Point }, style: ShapeStyle?): Image
```

Each draws on every frame. A rectangle's (x, y) is its top-left corner; circles and ellipses
are centered on (x, y). A polygon is closed and needs at least 3 points; a polyline is an open
path of at least 2. A `Point` is `{ x, y }` or `{ x = x, y = y }`.

```luau
type ShapeStyle = {
    fill: ColorInput?,
    stroke: ColorInput?,
    strokeWidth: number?, -- default 1
    antialias: boolean?,  -- default true
    radius: number?,      -- rounded corners, for drawRect
    dash: { number }?,    -- dash and gap lengths, such as { 6, 3 }
    lineCap: string?,     -- "butt", "round" or "square"
    lineJoin: string?,    -- "miter", "round" or "bevel"
}
```

Without `fill` or `stroke`, shapes are filled black and lines are stroked black. A shape with
only a `stroke` stays hollow.

```luau
local canvas = image.new(200, 120, "white")
canvas:drawRect(10, 10, 180, 100, { fill = "#ede7f6", stroke = "#5e35b1", strokeWidth = 2, radius = 12 })
canvas:drawLine(20, 60, 180, 60, { stroke = "gray", dash = { 6, 3 } })
canvas:drawPolygon({ { 100, 20 }, { 120, 50 }, { 80, 50 } }, { fill = "#5e35b1" })
```

#### img:drawText

```luau
img:drawText(text: string, x: number?, y: number?, style: TextStyle?): Image
```

Draws text on every frame. (x, y), default (0, 0), is the top-left corner of the text, or an
offset from the edge `style.gravity` names.

##### TextStyle

```luau
type TextStyle = {
    color: ColorInput?,      -- default black
    size: number?,           -- in points (default 16)
    font: string?,           -- a font file path, or a name from image.fonts()
    family: string?,         -- a font family, such as "DejaVu Sans"
    weight: number?,         -- 100 to 900; 700 is bold
    italic: boolean?,
    stroke: ColorInput?,     -- an outline around the letters
    strokeWidth: number?,
    gravity: Gravity?,       -- what x and y are relative to (default "top-left")
    angle: number?,          -- rotation in degrees
    background: ColorInput?, -- a box behind the text
    antialias: boolean?,
    kerning: number?,        -- extra space between letters
    lineSpacing: number?,    -- extra space between lines
    wordSpacing: number?,    -- extra space between words
}
```

Text may span several lines (`"\n"`). Without `font` or `family`, ImageMagick's default font
is used; an ImageMagick that has no font list of its own (Homebrew's) gets a common system
font instead (Arial, Helvetica or DejaVu Sans). For the same look on every machine, ship a font
file and pass its path as `font`.

```luau
img:drawText("Hello", 0, 24, { gravity = "top", size = 48, weight = 700, color = "white", stroke = "black" })
```

#### image.measureText

```luau
image.measureText(text: string, style: TextStyle?): TextMetrics
```

The size `text` would have when drawn with `style`, in pixels.

```luau
type TextMetrics = {
    width: number,
    height: number,
    ascent: number,  -- above the baseline
    descent: number, -- below the baseline (negative)
}
```

### Analysis

These look at the first frame.

#### img:compare

```luau
img:compare(other: Image, metric: string?): (number, Image)
```

How different two images of the same size are, and an image that highlights the differences.
`metric` is `"rmse"` by default, which goes from 0 (identical) to 1, or another of
ImageMagick's ([`image.options("metric")`](#imageoptions)), such as `"ae"`, the number of
pixels that differ. Raises if the sizes differ.

```luau
local distance, diff = actual:compare(expected)
if distance > 0.01 then
    diff:save("diff.png")
end
```

#### Other analysis methods

| Method | Returns |
|---|---|
| `img:stats()` | `{ mean, deviation, min, max }` over every channel, each from 0 to 1. |
| `img:histogram(limit?)` | `{ ColorCount }`: every color and its pixel count, most common first, at most `limit` of them. |
| `img:dominantColors(count?)` | `{ ColorCount }`: the image's main colors (default 5, at most 256), most common first. |
| `img:averageColor()` | The average `Color`. |
| `img:colorCount()` | The number of distinct colors. |

```luau
type ColorCount = {
    color: Color,
    hex: string,      -- "#rrggbb", or "#rrggbbaa" when not opaque
    count: number,    -- pixels with this color
    fraction: number, -- share of all the pixels, 0 to 1
}
```

`dominantColors` works on a copy reduced to at most 256 pixels on its longest side, so its
`count`s are of that copy; `fraction` is what to compare.

```luau
for _, c in img:dominantColors(3) do
    print(c.hex, math.round(c.fraction * 100) .. "%")
end
```

### Animation

An animated image is one `Image` with several frames. Each frame has a delay, and the whole
animation has a loop count.

| Method | Description |
|---|---|
| `img:coalesce()` | Turns optimized frames, which store only what changed, into complete frames. Do this before editing a GIF. |
| `img:optimize()` | Stores only what changes between frames, for smaller GIFs. Do this last. |
| `img:setDelay(milliseconds, frame?)` | Sets the delay of every frame, or only of `frame` (1-based). |
| `img:delays()` | Each frame's delay, in milliseconds. |
| `img:setLoop(count)` | How many times the animation plays; 0 loops forever. |

Delays are stored in hundredths of a second, so they are rounded to the nearest 10 ms.

```luau
local gif = image.load("in.gif"):coalesce()
gif:resize(240):setDelay(50)
gif:optimize():save("out.gif")

local frames = {}
for i = 0, 11 do
    table.insert(frames, image.new(64, 64, "white"):drawCircle(32, 32, 24, { fill = "none", stroke = "black" })
        :drawLine(32, 32, 32 + 20 * math.sin(i * math.pi / 6), 32 - 20 * math.cos(i * math.pi / 6)))
end
image.animate(frames, { delay = 100 }):save("clock.gif")
```

## Utilities

### image.formats

```luau
image.formats(): { string }
```

Every format this ImageMagick reads or writes, lowercase and sorted. Which ones there are
depends on how ImageMagick was built; its security policy (`policy.xml`) may also disable some,
such as PDF on several Linux distributions.

```luau
local canWebp = table.find(image.formats(), "webp") ~= nil
```

### image.fonts

```luau
image.fonts(): { string }
```

The font names usable as [`style.font`](#textstyle), sorted.

### image.options

```luau
image.options(kind: string): { string }
```

The names ImageMagick accepts for `kind`, sorted: `"alpha"`, `"channel"`, `"colorspace"`,
`"compose"`, `"distort"`, `"filter"`, `"kernel"`, `"linecap"`, `"linejoin"`, `"metric"`,
`"morphology"` or `"noise"`.

```luau
print(table.concat(image.options("filter"), ", ")) --> Bartlett, Bessel, Blackman, Bohman, Box, ...
```

### image.color

```luau
image.color(color: ColorInput): Color
```

Parses any color into channels from 0 to 255.

```luau
image.color("#5e35b1") --> { r = 94, g = 53, b = 177, a = 255 }
```

### image.hex

```luau
image.hex(color: ColorInput): string
```

`"#rrggbb"`, or `"#rrggbbaa"` when the color isn't opaque.

```luau
image.hex({ r = 255, g = 0, b = 0, a = 128 }) --> "#ff000080"
```

### image.limits

```luau
image.limits(limits: Limits?): Limits
```

Sets some of ImageMagick's resource limits, for the whole program, and returns all of them.

```luau
type Limits = {
    memory: number?,  -- bytes of memory for pixels before ImageMagick moves them to disk
    disk: number?,    -- bytes of disk for pixels
    map: number?,     -- bytes of memory-mapped files
    area: number?,    -- pixels in one image
    width: number?,   -- the widest image
    height: number?,  -- the tallest image
    threads: number?, -- threads one operation may use
    time: number?,    -- seconds an operation may take
    files: number?,   -- open files
}
```

An image over a limit fails to load. Set limits before handling images from untrusted
sources: a small file can claim to be enormous.

```luau
image.limits({ width = 8192, height = 8192, area = 40e6, memory = 256 * 1024 * 1024 })
```

### image.version

```luau
image.version: string
```

The version of ImageMagick in use, such as `"7.1.1-43"`.

## Example: thumbnails and a contact sheet

```luau
local fs = require("@sonata/fs")
local image = require("@sonata/image")

image.limits({ width = 16384, height = 16384 })

local thumbs = {}
for _, path in fs.glob("photos/*.{jpg,jpeg,png}") do
    local photo = image.load(path, { define = { ["jpeg:size"] = "640x640" } })
    photo:autoOrient():thumbnail(320, 320)
    photo:save("thumbs/" .. path:match("[^/]+$"):gsub("%.%w+$", ".webp"), { quality = 80 })
    table.insert(thumbs, photo)
end

image.grid(thumbs, { columns = 4, gap = 8, background = "white" }):save("contact-sheet.png")

for _, thumb in thumbs do
    thumb:close()
end
```

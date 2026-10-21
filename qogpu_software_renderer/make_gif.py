from pathlib import Path
from PIL import Image

FPS = 25
folder = Path(__file__).resolve().parent

# Sort numerically so frame_10 comes after frame_9.
files = sorted(
    (folder / "frames").glob("frame_*.ppm"),
    key=lambda p: int(p.stem.split("_")[-1])
)

if not files:
    raise SystemExit("No frame_*.ppm files found in frames/")

frames = []
for file in files:
    with Image.open(file) as image:
        frames.append(image.convert("RGB"))

frames[0].save(
    folder / "cube.gif",
    save_all=True,
    append_images=frames[1:],
    duration=1000 // FPS,
    loop=0
)

print(f"Saved cube.gif with {len(frames)} frames")
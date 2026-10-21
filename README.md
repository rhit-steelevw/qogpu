# qogpu

The Ada software reference renderer is in `qogpu_software_renderer/`.
It renders a rotating textured cube to 120 PPM frames for verification of
FPGA GPU output.

## Build and run

Install Alire with an Ada toolchain, then run from the repository root:

```powershell
cd qogpu_software_renderer
alr build
New-Item -ItemType Directory -Force frames
alr run
```

Run from the renderer directory so the relative `textures/` and `frames/`
paths resolve correctly. Alire regenerates the ignored `config/` directory.

To optionally combine the frames into `cube.gif`, install Python and Pillow:

```powershell
python -m pip install Pillow
python make_gif.py
```

Source, project metadata, and input textures are tracked. Build products,
Alire local state, and generated renders are ignored.

## Project documentation

- [Initial Architecture Proposal](docs/architecture-proposal.md)
- [Memory Management Discussion and Design Decisions](docs/memory-management-discussion.md)

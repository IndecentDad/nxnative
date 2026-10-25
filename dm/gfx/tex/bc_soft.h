// Software decoding of BC1–BC7 textures, for GPUs that cannot sample them (MTLDevice.supportsBCTextureCompression is NO: Apple A16 and older iPhone / iPad GPUs).
// nvn_fmt_to_mtl maps each BC format to the uncompressed format below while nvn_bc_soft is set, and the uploads decode the blocks into it (nvn_mtl.m).
// Pure C, no dependency on Metal headers; values are MTLPixelFormat numbers.
#pragma once
#include <stddef.h>
#include <stdint.h>

extern int nvn_bc_soft;   // 1 = BC textures are decoded on the CPU (set once the Metal device is known; DM_BC_SOFT=1 forces it, =0 turns it off)

// The uncompressed Metal format a BC Metal format decodes to and its bytes per pixel; 0 when mtl_pf is no BC format
//   BC1 / BC2 / BC3 / BC7 (and sRGB) → RGBA8Unorm (_sRGB), BC4 → R8Unorm / R8Snorm, BC5 → RG8Unorm / RG8Snorm, BC6H → RGBA16Float
uint32_t bc_soft_target(uint32_t mtl_pf, int *bytes_per_pixel);

// Decode a w × h region of BC blocks (src: rows of 4 × 4 blocks, src_pitch bytes from one block row to the next) into dst (dst_pitch bytes per pixel row).
// dst must hold whole blocks: ceil(w / 4) * 4 pixels per row and ceil(h / 4) * 4 rows. Returns 0, or -1 when mtl_pf is no BC format
int bc_soft_decode(uint32_t mtl_pf, const uint8_t *src, size_t src_pitch, uint32_t w, uint32_t h, uint8_t *dst, size_t dst_pitch);

// One 4 × 4 block into 16 pixels (row-major, bytes_per_pixel each), for tests
int bc_soft_block(uint32_t mtl_pf, const uint8_t *block, uint8_t *out, size_t out_pitch);

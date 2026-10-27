# Mario + Rabbids Kingdom Battle 1.9.589692, main build 3b39e0c06b8841f1baf0ea4d54286bfe.
# Snowdrop initializes three equal 4 GiB pools (large, 512 KiB, 64 KiB), then
# requests their 12 GiB enclosing address region without checking the result. Keep
# the equal per-class layout at 1 GiB each (3 GiB total), matching the 3,285 MiB
# application pool, and keep the large allocator page limit equal to 1 GiB / 64 KiB.
CUTS = {
  '3b39e0c06b8841f1baf0ea4d54286bfe': [
    (0xea2190, 'e80360b2', '0800a8d2', 'Snowdrop: three equal allocator ranges 4 GiB → 1 GiB (mov x8,#0x40000000)'),
    (0xea21c0, 'f60760b2', '1600b8d2', 'Snowdrop: combined allocator region 12 GiB → 3 GiB (mov x22,#0xc0000000)'),
    (0xea21cc, 'e00760b2', '0000b8d2', 'Snowdrop: AllocateAddressRegion request 12 GiB → 3 GiB (mov x0,#0xc0000000)'),
    (0xea21f4, 'e5031032', '05008852', 'Snowdrop large allocator: 64 KiB page ceiling 65,536 → 16,384, matching the 1 GiB range'),
  ],
}

# Porting notes

The donor repository is treated as a read-only reference. Its `BoardConfig.mk` is parsed for a side-by-side report, but not copied. Device-specific recovery portability depends on the target kernel, DTB/DTBO, display and touch drivers, partition layout, fstab, encryption implementation, vendor interfaces and boot image format.

For this X688B tree, the checked-in BoardConfig identifies `mt6765`, boot image header v2, a 33,554,432-byte boot partition and a 40,894,464-byte recovery partition. The current workflow replaces the tree's prebuilt kernel and DTB from the supplied stock X688B boot image (or `stock/dtb.img`), then builds against the X688B-specific tree.

No bootloader, AVB, vbmeta or userdata partition is modified by this workflow. Output is a build artifact only.

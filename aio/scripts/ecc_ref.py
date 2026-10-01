#!/usr/bin/env python3
"""Golden model for the 32-bit SEC-DED block used by AIO NAND DMA.

Commands:
    python scripts/ecc_ref.py selftest
    python scripts/ecc_ref.py gen sim/vectors/ecc_vectors.txt 1000 2026

Vector columns: data ecc corrupted_data corrupted_ecc status corrected_data.
Status: 0=clean, 1=data corrected, 2=ECC parity corrected, 3=uncorrectable.
"""

from __future__ import annotations

import random
import sys
from pathlib import Path

CLEAN, DATA_FIXED, PARITY_FIXED, UNCORRECTABLE = range(4)
PARITY_POSITIONS = {1, 2, 4, 8, 16, 32}


def encode(data: int) -> int:
    """Return the seven SEC-DED bits for one 32-bit word."""
    data &= 0xFFFF_FFFF
    code = [0] * 39  # positions 1..38; index 0 is unused
    data_bit = 0
    for pos in range(1, 39):
        if pos not in PARITY_POSITIONS:
            code[pos] = (data >> data_bit) & 1
            data_bit += 1

    ecc = 0
    for parity_bit, parity_pos in enumerate(sorted(PARITY_POSITIONS)):
        parity = 0
        for pos in range(1, 39):
            if pos & parity_pos:
                parity ^= code[pos]
        code[parity_pos] = parity
        ecc |= parity << parity_bit

    overall = 0
    for pos in range(1, 39):
        overall ^= code[pos]
    return ecc | (overall << 6)


def decode(data: int, stored_ecc: int) -> tuple[int, int, int]:
    """Return (corrected_data, status, syndrome)."""
    data &= 0xFFFF_FFFF
    stored_ecc &= 0x7F
    code = [0] * 39
    parity_positions = sorted(PARITY_POSITIONS)
    data_bit = 0
    for pos in range(1, 39):
        if pos in PARITY_POSITIONS:
            code[pos] = (stored_ecc >> parity_positions.index(pos)) & 1
        else:
            code[pos] = (data >> data_bit) & 1
            data_bit += 1

    syndrome = 0
    for parity_bit, parity_pos in enumerate(parity_positions):
        parity = 0
        for pos in range(1, 39):
            if pos & parity_pos:
                parity ^= code[pos]
        syndrome |= parity << parity_bit

    overall = (stored_ecc >> 6) & 1
    for pos in range(1, 39):
        overall ^= code[pos]

    if syndrome == 0 and overall == 0:
        return data, CLEAN, syndrome
    if syndrome == 0 and overall == 1:
        return data, PARITY_FIXED, syndrome
    if syndrome != 0 and overall == 1 and syndrome <= 38:
        if syndrome in PARITY_POSITIONS:
            return data, PARITY_FIXED, syndrome
        data_bit = 0
        for pos in range(1, 39):
            if pos not in PARITY_POSITIONS:
                if pos == syndrome:
                    return data ^ (1 << data_bit), DATA_FIXED, syndrome
                data_bit += 1
    return data, UNCORRECTABLE, syndrome


def selftest(seed: int = 2026) -> None:
    rng = random.Random(seed)
    corners = [0, 1, 0x8000_0000, 0xFFFF_FFFF, 0xA5A5_5A5A]
    samples = corners + [rng.getrandbits(32) for _ in range(1000)]

    for data in samples:
        ecc = encode(data)
        fixed, status, _ = decode(data, ecc)
        assert (fixed, status) == (data, CLEAN)

        for bit in range(32):
            fixed, status, _ = decode(data ^ (1 << bit), ecc)
            assert (fixed, status) == (data, DATA_FIXED), (data, bit)

        for bit in range(7):
            fixed, status, _ = decode(data, ecc ^ (1 << bit))
            assert fixed == data and status == PARITY_FIXED, (data, bit)

        for _ in range(10):
            bit_a, bit_b = rng.sample(range(32), 2)
            fixed, status, _ = decode(data ^ (1 << bit_a) ^ (1 << bit_b), ecc)
            assert status == UNCORRECTABLE, (data, bit_a, bit_b, fixed)

    print(
        "PASS: SEC-DED golden model - "
        f"{len(samples)} words, all 32 data-bit faults, all 7 ECC-bit faults, "
        "and 10 random double-bit faults per word"
    )


def generate(path: Path, count: int, seed: int) -> None:
    rng = random.Random(seed)
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="ascii", newline="\n") as stream:
        stream.write("# data ecc corrupted_data corrupted_ecc status corrected_data\n")
        for index in range(count):
            data = rng.getrandbits(32)
            ecc = encode(data)
            mode = index % 4
            bad_data, bad_ecc = data, ecc
            if mode == 1:
                bad_data ^= 1 << rng.randrange(32)
            elif mode == 2:
                bad_ecc ^= 1 << rng.randrange(7)
            elif mode == 3:
                a, b = rng.sample(range(32), 2)
                bad_data ^= (1 << a) | (1 << b)
            corrected, status, _ = decode(bad_data, bad_ecc)
            stream.write(
                f"{data:08x} {ecc:02x} {bad_data:08x} {bad_ecc:02x} "
                f"{status:x} {corrected:08x}\n"
            )
    print(f"wrote {count} deterministic vectors to {path}")


def main(argv: list[str]) -> int:
    if len(argv) == 2 and argv[1] == "selftest":
        selftest()
        return 0
    if len(argv) in (3, 4, 5) and argv[1] == "gen":
        count = int(argv[3]) if len(argv) >= 4 else 1000
        seed = int(argv[4]) if len(argv) >= 5 else 2026
        generate(Path(argv[2]), count, seed)
        return 0
    print(__doc__)
    return 2


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))

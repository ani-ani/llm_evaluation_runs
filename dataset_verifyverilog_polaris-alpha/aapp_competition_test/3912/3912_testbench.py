import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure
import random
import itertools

@cocotb.test()
async def test_palindrome(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    \
    async def reset():"""Reset the DUT"""
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        dut.start.value = 0
    \
    # Test cases (adapted to max n=16)
    test_vectors = [
        (6, [ord(c) for c in "aabaac"], 2, [b"aba", b"aca"]),
        (2, [ord(c) for c in "aA"], 2, [b"a", b"A"]),
        (8, [ord(c) for c in "0rTrT022"], 1, [b"02TrrT20"]),
        (1, [ord(c) for c in "s"], 1, [b"s"]),
        (4, [ord(c) for c in "aabb"], 1, [b"abba"])  # Added test case
    ]
    \
    passed = 0
    dut._log.info(f"Starting {len(test_vectors)} tests")
    await reset()
    \
    for (n_val, s_arr, exp_k, exp_parts) in test_vectors:
        # Apply inputs
        dut.n.value = n_val
        for i in range(16):
            dut.s[i].value = s_arr[i] if i < n_val else 0
        \
        # Start processing
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        \
        # Wait for completion (100 cycles)
        for _ in range(100):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        else:
            raise TestFailure(f"Timeout for test case n={n_val}")
        \
        # Check results
        k = dut.k.value
        if int(k) != exp_k:
            dut._log.error(f"n={n_val} k_error: got {k}, expected {exp_k}")
            continue
        \
        # Verify palindrome count/arrangement
        passing = True
        part_len = n_val // exp_k
        expected = [sorted(p) for p in exp_parts]  # Compare sorted char sets
        for i in range(exp_k):
            part_chars = bytes([dut.parts[i*16 + j].value for j in range(part_len)])
            \
            # Check palindrome property
            if part_chars != part_chars[::-1]:
                dut._log.error(f"n={n_val} part {i} not palindrome: {part_chars}")
                passing = False
            \
            # Check character composition matches
            sorted_part = sorted(part_chars)
            if sorted_part != expected[i]:
                dut._log.error(f"n={n_val} part {i} chars mismatch: {sorted_part} vs {expected[i]}")
                passing = False
        \
        if passing:
            passed += 1
    \
    dut._log.info(f"{passed}/{len(test_vectors)} tests passed")
    if passed < len(test_vectors):
        raise TestFailure("Some tests failed")
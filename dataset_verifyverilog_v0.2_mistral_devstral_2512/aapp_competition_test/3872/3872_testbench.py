import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure
import random

def canonical_sort(s):
    """Computes the canonical sorted form of the string for comparison."""
    if len(s) % 2 == 1:
        return s
    half = len(s) // 2
    s1 = canonical_sort(s[:half])
    s2 = canonical_sort(s[half:])
    return s1 + s2 if s1 < s2 else s2 + s1

def string_to_bytes(s, length=16):
    """Pads string to length and converts to integer value."""
    padded = s.ljust(length, '\x00')
    val = 0
    for i, char in enumerate(padded):
        val |= (ord(char) << (8 * (length - 1 - i)))
    return val

def int_to_bytes(val, length=16):
    """Extracts bytes from integer for comparison."""
    chars = []
    for i in range(length):
        byte = (val >> (8 * (length - 1 - i))) & 0xFF
        chars.append(chr(byte) if byte > 0 else '\x00')
    return ''.join(chars)

def bytes_to_string(b_str):
    """Removes null padding."""
    return b_str.rstrip('\x00')

@cocotb.test()
async def test_string_equivalence(dut):
    # Create a clock (50MHz)
    clock = Clock(dut.clk, 20, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.string_a.value = 0
    dut.string_b.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test cases (scaled to 16 chars max)
    test_cases = [
        ("aaba", "abaa", True),
        ("aabb", "abab", False),
        ("a", "a", True),
        ("a", "b", False),
        ("ab", "ab", True),
        ("ab", "ba", True),
        ("ab", "bb", False),
        ("zzaa", "aazz", True),
        ("azza", "zaaz", True),
        ("abc", "abc", True),
        ("abc", "acb", False),
        ("azzz", "zzaz", True),
        ("abcd", "dcab", True),
        ("abcd", "cdab", True),
        ("abcd", "dcba", True),
        ("abcd", "acbd", False),
        ("aab", "aba", False),
        ("abcddd", "bacddd", False),
        ("abc", "bac", False)
    ]

    passed = 0
    total = len(test_cases)

    for s1, s2, expected in test_cases:
        # Prepare inputs
        val_a = string_to_bytes(s1)
        val_b = string_to_bytes(s2)
        
        dut.string_a.value = val_a
        dut.string_b.value = val_b
        
        # Start pulse
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 100
        for _ in range(timeout):
            if dut.done.value == 1:
                break
            await RisingEdge(dut.clk)
        
        if dut.done.value != 1:
            raise TestFailure(f"Timeout for input '{s1}', '{s2}'")
            
        result = int(dut.equivalent.value)
        
        if result == (1 if expected else 0):
            passed += 1
        else:
            print(f"FAIL: Input '{s1}', '{s2}'. Expected {'YES' if expected else 'NO'}, got {'YES' if result else 'NO'}")
            # We don't raise failure to allow counting, but print error
            # raise TestFailure(f"Mismatch for {s1}, {s2}")

        await RisingEdge(dut.clk)

    print(f"
Summary: {passed}/{total} tests passed.")
    if passed < total:
        raise TestFailure(f"{total - passed} tests failed.")

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure
import random

# Helper function to pack string into 64-bit integer
# Characters are packed: char at index 0 (LSB) to index 7 (MSB)
def pack_string(s):
    val = 0
    for i, char in enumerate(s):
        val |= (ord(char) << (i * 8))
    return val

# Helper to check definedness
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_cycpattern_check(dut):
    """Test the cycpattern_check module"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.a.value = 0
    dut.b.value = 0
    dut.len.value = 0
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (A, B, Expected Result)
    # Note: "abab", "aabb" -> False (Standard logic: rotations of "aabb" are aabb, abba, bbaa, baab. None in "abab")
    # Note: "efef", "fee" -> True (Standard logic: "fee" rotations: fee, eef, efe. "efe" is in "efef")
    test_cases = [
        ("xyzw", "xyw", 0), # test #0: "xyw" not in "xyzw"
        ("yello", "ell", 1), # test #1: "ell" in "yello"
        ("whattup", "ptut", 0), # test #2: rotations of "ptut": ptut, tutp, utpt, tptu. None in "whattup"
        ("efef", "fee", 1), # test #3: "efe" rotation of "fee" is in "efef"
        ("abab", "aabb", 0), # test #4: rotations of "aabb" not in "abab"
        ("winemtt", "tinem", 1), # test #5: "tinem" in "winemtt"
        ("abcd", "abd", 0), # prompt example 1
        ("hello", "ell", 1), # prompt example 2
        ("whassup", "psus", 0), # prompt example 3
        ("abab", "baa", 1), # prompt example 4: "baa" rotations: baa, aab, aba. "aba" is in "abab"? "abab" has "aba" (indices 0-2) and "bab" (indices 1-3). Wait, "aba" is indices 0,1,2? 'a','b','a'. Yes. So True.
        ("efef", "eeff", 0), # prompt example 5
        ("himenss", "simen", 1), # prompt example 6
    ]

    passed = 0
    total = len(test_cases)

    dut._log.info(f"Starting {total} tests...")

    for i, (str_a, str_b, expected) in enumerate(test_cases):
        dut._log.info(f"Test {i}: A='{str_a}', B='{str_b}', Expected={expected}")
        
        len_val = max(len(str_a), len(str_b))
        # If strings are unequal length in test, we might need to handle padding or reject.
        # However, the problem implies equal length or substring check.
        # The test cases seem to have equal lengths or close enough.
        # Let's assume len is passed as the length of B (and A is usually longer or equal).
        # The prompt says "length of both strings". We will pass min(len(A), len(B))? 
        # Actually, for substring check, A must be >= B. 
        # The provided test cases: "yello" (5) vs "ell" (3). 
        # If we pass len=3, we check if rotations of "ell" are in first 3 chars of "yello"? No.
        # The prompt implies `len` is length of strings.
        # Let's use `len = length of B`. The hardware logic will check if rotation of B (length len) is a substring of A.
        # We need to be careful: if A is shorter than B, it can't be a substring. 
        # The tests "yello" (len 5) "ell" (len 3). "winemtt" (7) "tinem" (5).
        # We will pass `len` of B. 
        
        dut.len.value = len(str_b)
        dut.a.value = pack_string(str_a)
        dut.b.value = pack_string(str_b)
        
        # Start pulse
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done with timeout
        done_seen = False
        for cycle in range(1000): # Timeout cycles
            if not is_value_defined(dut.done.value):
                await RisingEdge(dut.clk)
                continue
            if dut.done.value == 1:
                done_seen = True
                break
            await RisingEdge(dut.clk)
        
        if not done_seen:
            raise TestFailure(f"Test {i}: Timeout waiting for done signal")
            
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Test {i}: Result is undefined (X/Z)")
            
        result = int(dut.result.value)
        
        if result != expected:
            raise TestFailure(f"Test {i}: A='{str_a}', B='{str_b}' -> Expected {expected}, got {result}")
        
        passed += 1
        # Small delay between tests
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)

    dut._log.info(f"Summary: {passed}/{total} tests passed")
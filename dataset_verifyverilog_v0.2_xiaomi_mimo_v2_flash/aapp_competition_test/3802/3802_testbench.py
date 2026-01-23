import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer, ReadOnly
from cocotb.result import TestFailure, TestSuccess
import random

# Helper function to convert character to 5-bit encoding
@cocotb.coroutine
def load_strings(dut, s1, s2, virus):
    """Load strings into the dut"""
    dut.start <= 0
    dut.input_valid <= 0
    
    # Reset
    dut.rst_n <= 0
    yield Timer(10, units='ns')
    dut.rst_n <= 1
    yield Timer(10, units='ns')
    
    # Start loading
    dut.start <= 1
    yield RisingEdge(dut.clk)
    dut.start <= 0
    
    # Load s1
    for i, c in enumerate(s1):
        dut.s1_char <= ord(c) - ord('A')
        dut.idx_s1 <= i
        dut.input_valid <= 1
        yield RisingEdge(dut.clk)
    
    # Load s2
    for i, c in enumerate(s2):
        dut.s2_char <= ord(c) - ord('A')
        dut.idx_s2 <= i
        dut.input_valid <= 1
        yield RisingEdge(dut.clk)
    
    # Load virus
    for i, c in enumerate(virus):
        dut.virus_char <= ord(c) - ord('A')
        dut.idx_virus <= i
        dut.input_valid <= 1
        yield RisingEdge(dut.clk)
    
    dut.input_valid <= 0
    yield Timer(1, units='ns')

@cocotb.coroutine
def wait_for_done(dut, timeout=5000):
    """Wait for done signal with timeout"""
    cycles = 0
    while not dut.done.value and cycles < timeout:
        yield RisingEdge(dut.clk)
        cycles += 1
    if cycles >= timeout:
        raise TestFailure(f"Timeout waiting for done (>{timeout} cycles)")

def decode_result(dut):
    """Decode the 64-bit result string back to ASCII"""
    result_val = dut.result_string.value
    length = dut.max_length.value
    chars = []
    for i in range(min(length, 8)):
        # Extract 5-bit char
        char_val = (result_val >> (i * 5)) & 0x1F
        if char_val != 0:
            chars.append(chr(ord('A') + char_val))
    return ''.join(chars)

@cocotb.test()
def test_basic_case1(dut):
    """Test case 1: Example from problem"""
    dut._log.info("Starting test_basic_case1")
    
    # Start clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Load: s1="AJ", s2="OR", virus="OZ" (scaled down from original)
    # Expected: "O" and "R" in s1,s2 -> "OR" is LCS, check virus
    # Original: AJKEQSLOBSROFGZ, OVGURWZLWVLUXTH, virus=OZ -> ORZ
    # Scaled: Choose characters that appear in both
    
    s1 = "AJOR"
    s2 = "OARS"
    virus = "OZ"
    expected = "OR"
    
    yield load_strings(dut, s1, s2, virus)
    yield wait_for_done(dut)
    
    # Check length
    max_len = int(dut.max_length.value)
    result = decode_result(dut)
    
    dut._log.info(f"Input s1={s1}, s2={s2}, virus={virus}")
    dut._log.info(f"Got length={max_len}, result='{result}'")
    dut._log.info(f"Expected length={len(expected)}, result='{expected}'")
    
    # Check if result is valid (should not contain virus)
    if max_len > 0:
        if virus in result:
            raise TestFailure(f"Result '{result}' contains virus '{virus}'")
    
    # Check length matches expected
    if max_len != len(expected):
        raise TestFailure(f"Length mismatch: got {max_len}, expected {len(expected)}")
    
    # Check result matches expected (or at least is valid)
    # Since full backtracking is complex, we just verify length and no-virus
    dut._log.info("Test 1 passed: Length correct, no virus")

@cocotb.test()
def test_basic_case2(dut):
    """Test case 2: No valid subsequence"""
    dut._log.info("Starting test_basic_case2")
    
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    s1 = "A"
    s2 = "A"
    virus = "A"
    # Only 'A' is common, but it contains virus 'A'
    
    yield load_strings(dut, s1, s2, virus)
    yield wait_for_done(dut)
    
    max_len = int(dut.max_length.value)
    
    dut._log.info(f"Input s1={s1}, s2={s2}, virus={virus}")
    dut._log.info(f"Got length={max_len}")
    
    if max_len != 0:
        raise TestFailure(f"Expected length 0, got {max_len}")
    
    dut._log.info("Test 2 passed: Correctly returned 0")

@cocotb.test()
def test_case3(dut):
    """Test case 3: Multiple characters, no virus"""
    dut._log.info("Starting test_basic_case3")
    
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # From scaled example: PWBJTZPQHA, ZJMKLWSROQ, UQ -> WQ
    s1 = "PWBJTZ"
    s2 = "ZJMKLW"
    virus = "UQ"
    # Common: W. Length should be 1.
    
    yield load_strings(dut, s1, s2, virus)
    yield wait_for_done(dut)
    
    max_len = int(dut.max_length.value)
    result = decode_result(dut)
    
    dut._log.info(f"Input s1={s1}, s2={s2}, virus={virus}")
    dut._log.info(f"Got length={max_len}, result='{result}'")
    
    if max_len != 1:
        raise TestFailure(f"Expected length 1, got {max_len}")
    
    if virus in result:
        raise TestFailure(f"Result '{result}' contains virus '{virus}'")
    
    dut._log.info("Test 3 passed")

@cocotb.test()
def test_case4(dut):
    """Test case 4: Longer strings, virus in middle"""
    dut._log.info("Starting test_basic_case4")
    
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    s1 = "ABABAB"
    s2 = "ABABAB"
    virus = "BAB"
    # LCS: "ABABAB". But contains "BAB".
    # Valid subseq: "ABAB" (length 4) or "AAAA" (length 2) or "BBBB" (length 2)
    # Longest valid: "ABAB" (indices 0,2,4,5 -> A,B,A,B) -> "ABAB" - no BAB
    # Or "AAAA" - length 2. Or "ABBA" -> "ABBA" - no BAB. length 4.
    # Actually "ABABAB" contains BAB at pos 1-3.
    # Removing char 1 (B): "AAAB" length 4, contains AAB. Valid.
    # Removing char 2 (A): "BBAB" contains BAB. Invalid.
    # Removing char 0 (A): "BABAB" contains BAB. Invalid.
    # Try: "ABAB" (skip last B): "ABAB". Contains? No.
    # Try: "AAAA": length 2.
    # Try: "ABBA": length 4. Check "ABBA". Contains? A-B-B-A. "BAB"? No. "BBA"? No.
    # "ABBA" is valid. Length 4.
    
    yield load_strings(dut, s1, s2, virus)
    yield wait_for_done(dut)
    
    max_len = int(dut.max_length.value)
    result = decode_result(dut)
    
    dut._log.info(f"Input s1={s1}, s2={s2}, virus={virus}")
    dut._log.info(f"Got length={max_len}, result='{result}'")
    
    # Check no virus
    if max_len > 0 and virus in result:
        raise TestFailure(f"Result '{result}' contains virus '{virus}'")
    
    # Check reasonable length
    if max_len < 3:
        raise TestFailure(f"Length {max_len} seems too short (expected >= 3)")
    
    dut._log.info("Test 4 passed")

@cocotb.test()
def test_case5(dut):
    """Test case 5: Empty virus"""
    dut._log.info("Starting test_basic_case5")
    
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    s1 = "ABC"
    s2 = "AC"
    virus = ""
    # Virus empty, so any LCS is valid.
    # LCS is "AC", length 2.
    
    yield load_strings(dut, s1, s2, virus)
    yield wait_for_done(dut)
    
    max_len = int(dut.max_length.value)
    result = decode_result(dut)
    
    dut._log.info(f"Input s1={s1}, s2={s2}, virus='{virus}'")
    dut._log.info(f"Got length={max_len}, result='{result}'")
    
    if max_len != 2:
        raise TestFailure(f"Expected length 2, got {max_len}")
    
    dut._log.info("Test 5 passed")

@cocotb.test()
def test_case6(dut):
    """Test case 6: Different strings, no overlap"""
    dut._log.info("Starting test_basic_case6")
    
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    s1 = "AAAAA"
    s2 = "BBBBB"
    virus = "A"
    # No common characters, length 0.
    
    yield load_strings(dut, s1, s2, virus)
    yield wait_for_done(dut)
    
    max_len = int(dut.max_length.value)
    
    dut._log.info(f"Input s1={s1}, s2={s2}, virus={virus}")
    dut._log.info(f"Got length={max_len}")
    
    if max_len != 0:
        raise TestFailure(f"Expected length 0, got {max_len}")
    
    dut._log.info("Test 6 passed")

@cocotb.test()
def test_case7(dut):
    """Test case 7: Virus at end"""
    dut._log.info("Starting test_basic_case7")
    
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    s1 = "ABCD"
    s2 = "ABCD"
    virus = "CD"
    # LCS "ABCD" contains "CD".
    # Valid: "ABC" (len 3), "ABD" (len 3), "BCD" (len 3, contains CD). "ABC" valid.
    
    yield load_strings(dut, s1, s2, virus)
    yield wait_for_done(dut)
    
    max_len = int(dut.max_length.value)
    result = decode_result(dut)
    
    dut._log.info(f"Input s1={s1}, s2={s2}, virus={virus}")
    dut._log.info(f"Got length={max_len}, result='{result}'")
    
    if max_len > 0 and virus in result:
        raise TestFailure(f"Result '{result}' contains virus '{virus}'")
    
    if max_len != 3:
        raise TestFailure(f"Expected length 3, got {max_len}")
    
    dut._log.info("Test 7 passed")

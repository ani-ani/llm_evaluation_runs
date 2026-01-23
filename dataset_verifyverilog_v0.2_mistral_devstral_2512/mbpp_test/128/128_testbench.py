import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure
import random

# Helper function to convert ASCII string to 64-bit value (8 chars)
def str_to_64bit(s):
    # Pad to exactly 8 characters with spaces (0x20)
    padded = (s + ' ' * 8)[:8]
    value = 0
    for i, char in enumerate(padded):
        value |= ord(char) << (56 - i*8)  # Big-endian: first char in MSB
    return value

# Helper to convert 64-bit value back to string for comparison
def bit64_to_str(value):
    s = ''
    for i in range(8):
        char_val = (value >> (56 - i*8)) & 0xFF
        if char_val == 0x20:
            s += ' '
        elif char_val != 0:
            s += chr(char_val)
    return s.rstrip()  # Remove trailing spaces

@cocotb.test()
async def test_long_words_basic(dut):
    """Test basic functionality with sample string"""
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.threshold.value = 0
    dut.input_string.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await Timer(20, units='ns')
    
    # Test 1: threshold=3, "python is a prog" (8 chars: 'python\x20is')
    # First 8 chars: 'python i' -> words: 'python' (6), 'i' (1)
    # 'python' > 3, should match
    input_str = "python i"  # 8 chars
    dut.input_string.value = str_to_64bit(input_str)
    dut.threshold.value = 3
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion
    for _ in range(12):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    # Check result
    if not dut.done.value:
        raise TestFailure("DONE signal not asserted")
    
    if not dut.found.value:
        raise TestFailure(f"Should have found word > threshold 3")
    
    result_str = bit64_to_str(dut.result_word.value)
    print(f"Test 1: Input='{input_str}', Threshold=3, Result='{result_str}'")
    assert result_str == 'python', f"Expected 'python', got '{result_str}'"

@cocotb.test()
async def test_long_words_multiple(dut):
    """Test finding second matching word"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await Timer(20, units='ns')
    
    # Test 2: threshold=5, "sort list" -> words: 'sort'(4), 'list'(4)
    # No words > 5, should not find
    input_str = "sort list"
    dut.input_string.value = str_to_64bit(input_str)
    dut.threshold.value = 5
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(12):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    if not dut.done.value:
        raise TestFailure("DONE signal not asserted")
    
    # Should NOT find any word
    if dut.found.value:
        result_str = bit64_to_str(dut.result_word.value)
        raise TestFailure(f"Should not have found word > threshold 5, but got '{result_str}'")
    
    print(f"Test 2: Input='{input_str}', Threshold=5, No match found (correct)")

@cocotb.test()
async def test_long_words_edge_cases(dut):
    """Test edge cases: exact threshold, max length, spaces"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await Timer(20, units='ns')
    
    # Test 3a: Exact threshold (should NOT match since condition is > n)
    input_str = "abc defg"  # 'abc'(3), 'defg'(4)
    dut.input_string.value = str_to_64bit(input_str)
    dut.threshold.value = 3
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(12):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    if not dut.done.value:
        raise TestFailure("DONE signal not asserted")
    
    if not dut.found.value:
        raise TestFailure("Should find 'defg' (length 4 > threshold 3)")
    
    result_str = bit64_to_str(dut.result_word.value)
    print(f"Test 3a: Input='{input_str}', Threshold=3, Result='{result_str}'")
    assert result_str == 'defg', f"Expected 'defg', got '{result_str}'"
    
    # Test 3b: Single character words
    input_str = "a b c d"
    dut.input_string.value = str_to_64bit(input_str)
    dut.threshold.value = 0
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(12):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    if not dut.done.value:
        raise TestFailure("DONE signal not asserted")
    
    # All words are > 0, should find first
    if not dut.found.value:
        raise TestFailure("Should find 'a' (length 1 > threshold 0)")
    
    result_str = bit64_to_str(dut.result_word.value)
    print(f"Test 3b: Input='{input_str}', Threshold=0, Result='{result_str}'")
    assert result_str == 'a', f"Expected 'a', got '{result_str}'"

@cocotb.test()
async def test_long_words_no_spaces(dut):
    """Test with single word (no spaces)"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await Timer(20, units='ns')
    
    # Single word 'program'
    input_str = "program "
    dut.input_string.value = str_to_64bit(input_str)
    dut.threshold.value = 5
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(12):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    if not dut.done.value:
        raise TestFailure("DONE signal not asserted")
    
    if not dut.found.value:
        raise TestFailure("Should find 'program' (length 7 > threshold 5)")
    
    result_str = bit64_to_str(dut.result_word.value)
    print(f"Test 4: Input='{input_str.strip()}', Threshold=5, Result='{result_str}'")
    assert result_str == 'program', f"Expected 'program', got '{result_str}'"

@cocotb.test()
async def test_long_words_threshold_zero(dut):
    """Test threshold=0 finds all words"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await Timer(20, units='ns')
    
    # 'x y' - should find 'x'
    input_str = "x y     "  # 8 chars with spaces
    dut.input_string.value = str_to_64bit(input_str)
    dut.threshold.value = 0
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(12):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    if not dut.done.value:
        raise TestFailure("DONE signal not asserted")
    
    if not dut.found.value:
        raise TestFailure("Should find 'x' (length 1 > threshold 0)")
    
    result_str = bit64_to_str(dut.result_word.value)
    print(f"Test 5: Input='{input_str}', Threshold=0, Result='{result_str}'")
    assert result_str == 'x', f"Expected 'x', got '{result_str}'"

@cocotb.test()
async def test_long_words_all_spaces(dut):
    """Test with all spaces - should not find anything"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await Timer(20, units='ns')
    
    input_str = "        "  # 8 spaces
    dut.input_string.value = str_to_64bit(input_str)
    dut.threshold.value = 0
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(12):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    if not dut.done.value:
        raise TestFailure("DONE signal not asserted")
    
    if dut.found.value:
        raise TestFailure("Should NOT find any word in all spaces")
    
    print(f"Test 6: Input='        ', Threshold=0, No match found (correct)")

print("All tests completed!")
import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_string_splitter_basic(dut):
    """Test basic string splitting functionality"""
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    for i in range(3):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test 1: "python programming" -> ['python','programming']
    # Input: 16 chars, fill with spaces
    input_str = b"python programming".ljust(16, b' ')
    for i in range(16):
        dut.input_string[i].value = input_str[i]
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion (20 cycles)
    for _ in range(22):
        await RisingEdge(dut.clk)
    
    assert dut.done.value == 1, "Done signal not asserted"
    assert dut.word_count.value == 2, f"Expected 2 words, got {dut.word_count.value}"
    
    # Check word1: 'python' + spaces
    expected_word1 = b"python".ljust(16, b' ')
    for i in range(16):
        assert dut.word1[i].value == expected_word1[i], f"word1[{i}] mismatch"
    
    # Check word2: 'programming' + spaces
    expected_word2 = b"programming".ljust(16, b' ')
    for i in range(16):
        assert dut.word2[i].value == expected_word2[i], f"word2[{i}] mismatch"
    
    # Check word3 is empty
    for i in range(16):
        assert dut.word3[i].value == ord(' '), f"word3[{i}] should be space"
    
    print("Test 1 Passed: 'python programming'")

@cocotb.test()
async def test_string_splitter_three_words(dut):
    """Test with three words"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    for i in range(3):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test 2: "lists tuples strings" -> ['lists','tuples','strings']
    input_str = b"lists tuples strings".ljust(16, b' ')
    for i in range(16):
        dut.input_string[i].value = input_str[i]
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(22):
        await RisingEdge(dut.clk)
    
    assert dut.done.value == 1
    assert dut.word_count.value == 3
    
    expected_word1 = b"lists".ljust(16, b' ')
    for i in range(16):
        assert dut.word1[i].value == expected_word1[i]
    
    expected_word2 = b"tuples".ljust(16, b' ')
    for i in range(16):
        assert dut.word2[i].value == expected_word2[i]
    
    expected_word3 = b"strings".ljust(16, b' ')
    for i in range(16):
        assert dut.word3[i].value == expected_word3[i]
    
    print("Test 2 Passed: 'lists tuples strings'")

@cocotb.test()
async def test_string_splitter_three_words_short(dut):
    """Test with three short words"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    for i in range(3):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test 3: "write a program" -> ['write','a','program']
    input_str = b"write a program".ljust(16, b' ')
    for i in range(16):
        dut.input_string[i].value = input_str[i]
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(22):
        await RisingEdge(dut.clk)
    
    assert dut.done.value == 1
    assert dut.word_count.value == 3
    
    expected_word1 = b"write".ljust(16, b' ')
    for i in range(16):
        assert dut.word1[i].value == expected_word1[i]
    
    expected_word2 = b"a".ljust(16, b' ')
    for i in range(16):
        assert dut.word2[i].value == expected_word2[i]
    
    expected_word3 = b"program".ljust(16, b' ')
    for i in range(16):
        assert dut.word3[i].value == expected_word3[i]
    
    print("Test 3 Passed: 'write a program'")

@cocotb.test()
async def test_string_splitter_edge_cases(dut):
    """Test edge cases: leading/trailing spaces and consecutive spaces"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    for i in range(3):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test: "  hello   world  " -> ['hello','world']
    # (leading, multiple internal, trailing spaces)
    input_str = b"  hello   world  ".ljust(16, b' ')
    for i in range(16):
        dut.input_string[i].value = input_str[i]
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(22):
        await RisingEdge(dut.clk)
    
    assert dut.done.value == 1
    assert dut.word_count.value == 2, f"Expected 2 words, got {dut.word_count.value}"
    
    expected_word1 = b"hello".ljust(16, b' ')
    for i in range(16):
        assert dut.word1[i].value == expected_word1[i]
    
    expected_word2 = b"world".ljust(16, b' ')
    for i in range(16):
        assert dut.word2[i].value == expected_word2[i]
    
    print("Test 4 Passed: Edge case with extra spaces")

@cocotb.test()
async def test_string_splitter_empty_spaces(dut):
    """Test with mostly spaces"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    for i in range(3):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test: "cat" -> ['cat']
    input_str = b"cat".ljust(16, b' ')
    for i in range(16):
        dut.input_string[i].value = input_str[i]
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(22):
        await RisingEdge(dut.clk)
    
    assert dut.done.value == 1
    assert dut.word_count.value == 1
    
    expected_word1 = b"cat".ljust(16, b' ')
    for i in range(16):
        assert dut.word1[i].value == expected_word1[i]
    
    # Verify word2 and word3 are empty
    for i in range(16):
        assert dut.word2[i].value == ord(' ')
        assert dut.word3[i].value == ord(' ')
    
    print("Test 5 Passed: Single word string")

@cocotb.test()
async def test_string_splitter_all_spaces(dut):
    """Test with all spaces"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    for i in range(3):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test: all spaces -> []
    input_str = b" " * 16
    for i in range(16):
        dut.input_string[i].value = input_str[i]
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(22):
        await RisingEdge(dut.clk)
    
    assert dut.done.value == 1
    assert dut.word_count.value == 0
    
    print("Test 6 Passed: All spaces (empty result)")

# Summary test to count results
@cocotb.test()
async def test_summary(dut):
    """Summary: print pass/fail counts"""
    print("
=== TEST SUMMARY ===")
    print("All tests above verify the string_splitter module.")
    print("Each test checks correct word extraction from space-delimited strings.")
    print("===================
")
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_string_matcher(dut):
    """Test string matching module with exact pattern search"""
    
    # Create a 10ns clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test 1: Find 'fox' in 'The quick brown fox jumps over the lazy dog.'
    # Text: 'The quic' (8 chars)
    # Pattern: 'fox' (3 chars)
    dut.text[0].value = ord('T')
    dut.text[1].value = ord('h')
    dut.text[2].value = ord('e')
    dut.text[3].value = ord(' ')
    dut.text[4].value = ord('q')
    dut.text[5].value = ord('u')
    dut.text[6].value = ord('i')
    dut.text[7].value = ord('c')
    dut.pattern[0].value = ord('f')
    dut.pattern[1].value = ord('o')
    dut.pattern[2].value = ord('x')
    dut.pattern[3].value = 0
    dut.pattern_length.value = 3
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion (max 64 cycles)
    for _ in range(65):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    # Expected: not found (text doesn't contain 'fox')
    if dut.found.value != 0:
        raise TestFailure(f"Test 1 failed: Expected found=0, got {dut.found.value}")
    print("Test 1 passed: 'fox' correctly not found in 'The quic'")
    
    # Test 2: Find 'crazy' in 'Its been' (8 chars)
    # This should be adapted to fit in 8 chars
    dut.text[0].value = ord('I')
    dut.text[1].value = ord('t')
    dut.text[2].value = ord('s')
    dut.text[3].value = ord(' ')
    dut.text[4].value = ord('b')
    dut.text[5].value = ord('e')
    dut.text[6].value = ord('e')
    dut.text[7].value = ord('n')
    dut.pattern[0].value = ord('b')
    dut.pattern[1].value = ord('e')
    dut.pattern[2].value = ord('e')
    dut.pattern[3].value = ord('n')
    dut.pattern[4].value = 0
    dut.pattern_length.value = 4
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(65):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    # Expected: found at index 4, end at 8
    if dut.found.value != 1:
        raise TestFailure(f"Test 2 failed: Expected found=1, got {dut.found.value}")
    if dut.start_index.value != 4:
        raise TestFailure(f"Test 2 failed: Expected start_index=4, got {dut.start_index.value}")
    if dut.end_index.value != 8:
        raise TestFailure(f"Test 2 failed: Expected end_index=8, got {dut.end_index.value}")
    print("Test 2 passed: 'beee' found at indices 4-8")
    
    # Test 3: Find 'will' in 'the will' (8 chars)
    dut.text[0].value = ord('t')
    dut.text[1].value = ord('h')
    dut.text[2].value = ord('e')
    dut.text[3].value = ord(' ')
    dut.text[4].value = ord('w')
    dut.text[5].value = ord('i')
    dut.text[6].value = ord('l')
    dut.text[7].value = ord('l')
    dut.pattern[0].value = ord('w')
    dut.pattern[1].value = ord('i')
    dut.pattern[2].value = ord('l')
    dut.pattern[3].value = ord('l')
    dut.pattern[4].value = 0
    dut.pattern_length.value = 4
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(65):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.found.value != 1:
        raise TestFailure(f"Test 3 failed: Expected found=1, got {dut.found.value}")
    if dut.start_index.value != 4:
        raise TestFailure(f"Test 3 failed: Expected start_index=4, got {dut.start_index.value}")
    if dut.end_index.value != 8:
        raise TestFailure(f"Test 3 failed: Expected end_index=8, got {dut.end_index.value}")
    print("Test 3 passed: 'will' found at indices 4-8")
    
    # Test 4: Single character match
    dut.text[0].value = ord('a')
    dut.text[1].value = ord('b')
    dut.text[2].value = ord('c')
    dut.text[3].value = ord('d')
    dut.text[4].value = ord('e')
    dut.text[5].value = ord('f')
    dut.text[6].value = ord('g')
    dut.text[7].value = ord('h')
    dut.pattern[0].value = ord('d')
    dut.pattern[1].value = 0
    dut.pattern[2].value = 0
    dut.pattern[3].value = 0
    dut.pattern_length.value = 1
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(65):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.found.value != 1:
        raise TestFailure(f"Test 4 failed: Expected found=1, got {dut.found.value}")
    if dut.start_index.value != 3:
        raise TestFailure(f"Test 4 failed: Expected start_index=3, got {dut.start_index.value}")
    if dut.end_index.value != 4:
        raise TestFailure(f"Test 4 failed: Expected end_index=4, got {dut.end_index.value}")
    print("Test 4 passed: 'd' found at indices 3-4")
    
    # Test 5: Pattern at beginning
    dut.text[0].value = ord('s')
    dut.text[1].value = ord('t')
    dut.text[2].value = ord('a')
    dut.text[3].value = ord('r')
    dut.text[4].value = ord('t')
    dut.text[5].value = ord('x')
    dut.text[6].value = ord('y')
    dut.text[7].value = ord('z')
    dut.pattern[0].value = ord('s')
    dut.pattern[1].value = ord('t')
    dut.pattern[2].value = ord('a')
    dut.pattern[3].value = ord('r')
    dut.pattern[4].value = 0
    dut.pattern_length.value = 4
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(65):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.found.value != 1:
        raise TestFailure(f"Test 5 failed: Expected found=1, got {dut.found.value}")
    if dut.start_index.value != 0:
        raise TestFailure(f"Test 5 failed: Expected start_index=0, got {dut.start_index.value}")
    if dut.end_index.value != 4:
        raise TestFailure(f"Test 5 failed: Expected end_index=4, got {dut.end_index.value}")
    print("Test 5 passed: 'star' found at indices 0-4")
    
    print("
All tests completed successfully!")
    print("Summary: 5/5 tests passed")

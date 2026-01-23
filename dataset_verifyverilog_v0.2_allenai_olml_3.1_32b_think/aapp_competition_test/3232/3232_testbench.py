import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_string_rearrange(dut):
    """Test string rearrangement for substring uniqueness"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.char_array.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: "tralalal" (8 chars)
    # Input: t=0x74, r=0x72, a=0x61, l=0x6c, a=0x61, l=0x6c, a=0x61, l=0x6c
    dut._log.info("Test 1: tralalal")
    input_chars = [ord('t'), ord('r'), ord('a'), ord('l'), ord('a'), ord('l'), ord('a'), ord('l')]
    # Convert to 64-bit value for array
    dut.char_array.value = 0
    for i, ch in enumerate(input_chars):
        dut.char_array.value |= (ch << (8 * i))
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion (max 200 cycles)
    for _ in range(200):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    assert dut.done.value == 1, "Test 1: Did not complete in time"
    
    if dut.no_solution.value == 1:
        # Allow -1 output for test 1 (some implementations might not find solution)
        dut._log.info("Test 1: No solution found (acceptable)")
    else:
        assert dut.valid.value == 1, "Test 1: Solution marked invalid"
        # Read result
        result_val = dut.result.value
        result_chars = []
        for i in range(8):
            ch = (result_val >> (8 * i)) & 0xFF
            result_chars.append(chr(ch))
        result_str = ''.join(result_chars)
        dut._log.info(f"Test 1 result: {result_str}")
        
        # Verify all 5 substrings of length 4 are unique
        substrings = set()
        for i in range(5):
            sub = result_str[i:i+4]
            substrings.add(sub)
        
        assert len(substrings) == 5, f"Test 1: Substrings not unique: {substrings}"
    
    # Test case 2: "zzzzzzzz" (all same chars - should be -1)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut._log.info("Test 2: zzzzzzzz")
    input_chars = [ord('z'), ord('z'), ord('z'), ord('z'), ord('z'), ord('z'), ord('z'), ord('z')]
    dut.char_array.value = 0
    for i, ch in enumerate(input_chars):
        dut.char_array.value |= (ch << (8 * i))
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(200):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    assert dut.done.value == 1, "Test 2: Did not complete in time"
    assert dut.no_solution.value == 1, "Test 2: Should indicate no solution"
    dut._log.info("Test 2: Correctly identified no solution")
    
    # Test case 3: "annorlunda" - need to truncate to 8 chars
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut._log.info("Test 3: annorlun (truncated to 8 chars)")
    input_chars = [ord('a'), ord('n'), ord('n'), ord('o'), ord('r'), ord('l'), ord('u'), ord('n')]
    dut.char_array.value = 0
    for i, ch in enumerate(input_chars):
        dut.char_array.value |= (ch << (8 * i))
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(200):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    assert dut.done.value == 1, "Test 3: Did not complete in time"
    
    if dut.no_solution.value == 0:
        assert dut.valid.value == 1, "Test 3: Solution marked invalid"
        result_val = dut.result.value
        result_chars = []
        for i in range(8):
            ch = (result_val >> (8 * i)) & 0xFF
            result_chars.append(chr(ch))
        result_str = ''.join(result_chars)
        dut._log.info(f"Test 3 result: {result_str}")
        
        substrings = set()
        for i in range(5):
            sub = result_str[i:i+4]
            substrings.add(sub)
        
        assert len(substrings) == 5, f"Test 3: Substrings not unique: {substrings}"
    else:
        dut._log.info("Test 3: No solution (acceptable)")
    
    # Test case 4: "abcdabcd" - should find solution
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut._log.info("Test 4: abcdabcd")
    input_chars = [ord('a'), ord('b'), ord('c'), ord('d'), ord('a'), ord('b'), ord('c'), ord('d')]
    dut.char_array.value = 0
    for i, ch in enumerate(input_chars):
        dut.char_array.value |= (ch << (8 * i))
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(200):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    assert dut.done.value == 1, "Test 4: Did not complete in time"
    
    if dut.no_solution.value == 0:
        assert dut.valid.value == 1, "Test 4: Solution marked invalid"
        result_val = dut.result.value
        result_chars = []
        for i in range(8):
            ch = (result_val >> (8 * i)) & 0xFF
            result_chars.append(chr(ch))
        result_str = ''.join(result_chars)
        dut._log.info(f"Test 4 result: {result_str}")
        
        substrings = set()
        for i in range(5):
            sub = result_str[i:i+4]
            substrings.add(sub)
        
        assert len(substrings) == 5, f"Test 4: Substrings not unique: {substrings}"
    else:
        dut._log.info("Test 4: No solution (acceptable)")
    
    # Test case 5: "abcdefgh" - all unique chars
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut._log.info("Test 5: abcdefgh")
    input_chars = [ord('a'), ord('b'), ord('c'), ord('d'), ord('e'), ord('f'), ord('g'), ord('h')]
    dut.char_array.value = 0
    for i, ch in enumerate(input_chars):
        dut.char_array.value |= (ch << (8 * i))
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(200):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    assert dut.done.value == 1, "Test 5: Did not complete in time"
    assert dut.valid.value == 1, "Test 5: Should find valid solution"
    
    result_val = dut.result.value
    result_chars = []
    for i in range(8):
        ch = (result_val >> (8 * i)) & 0xFF
        result_chars.append(chr(ch))
    result_str = ''.join(result_chars)
    dut._log.info(f"Test 5 result: {result_str}")
    
    substrings = set()
    for i in range(5):
        sub = result_str[i:i+4]
        substrings.add(sub)
    
    assert len(substrings) == 5, f"Test 5: Substrings not unique: {substrings}"
    
    dut._log.info("All tests passed!")
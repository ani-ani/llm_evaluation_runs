import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import string

@cocotb.test()
async def test_histogram(dut):
    # Generate clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [
        ("a b b a",    {'a', 'b'}, 2),
        ("a b c a b",  {'a', 'b'}, 2),
        ("b b b b a", {'b'},      4),
        ("r t g",      {'r','t','g'}, 1),
        ("a",          {'a'},      1)
    ]
    
    passed = 0
    for i, (input_str, expected_letters, expected_count) in enumerate(test_cases):
        # Convert string to ASCII stream
        chars = [ord(c) for c in input_str.replace(' ', '')]
        
        # Start processing
        dut.start.value = 1
        for j, char_val in enumerate(chars):
            dut.char_in.value = char_val
            dut.last_char.value = 1 if j == len(chars)-1 else 0
            await RisingEdge(dut.clk)
        dut.start.value = 0
        dut.last_char.value = 0
        
        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Check outputs
        max_letters = [c for c in string.ascii_lowercase 
                      if dut.max_letters.value[ord(c)-ord('a')]]
        result_set = set(max_letters)
        actual_count = dut.max_count.value.integer
        
        if (result_set == expected_letters and 
            actual_count == expected_count):
            passed += 1
            dut._log.info(f"Test {i+1} PASS: {input_str} -> {result_set} count={actual_count}")
        else:
            dut._log.error(f"Test {i+1} FAIL: {input_str} -> {result_set}(count={actual_count})
"
                          f"Expected: {expected_letters}(count={expected_count})")
        
        # Wait a cycle before next test
        await RisingEdge(dut.clk)
    
    # Empty string test
    dut.start.value = 1
    dut.char_in.value = 0
    dut.last_char.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    dut.last_char.value = 0
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    if dut.max_count.value == 0 and dut.max_letters.value == 0:
        passed += 1
        dut._log.info("Empty string test PASS")
    else:
        dut._log.error(f"Empty string FAIL: max_count={dut.max_count.value} letters={dut.max_letters.value}")
    
    # Edge case - single character
    dut.start.value = 1
    dut.char_in.value = ord('z')
    dut.last_char.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    dut.last_char.value = 0
    while not dut.done.value:
        await RisingEdge(dut.clk)
    if dut.max_letters.value[25] and dut.max_count.value == 1:
        passed += 1
        dut._log.info("Single char test PASS")
    else:
        dut._log.error(f"Single letter FAIL: max_count={dut.max_count.value} letters={dut.max_letters.value}")
    
    total_tests = len(test_cases) + 2
    dut._log.info(f"{passed}/{total_tests} tests passed")
    assert passed == total_tests
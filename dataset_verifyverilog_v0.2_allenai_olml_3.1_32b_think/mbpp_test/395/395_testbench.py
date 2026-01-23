import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_first_non_repeating_char(dut):
    """Test first non-repeating character finding"""
    
    # Create clock (10ns period)
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Initialize signals
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.char_array.value = [ord(' ') * (2**8) ** i for i in range(8)]
    
    # Reset
    await Timer(25, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test 1: "abcabc" -> no unique (all repeat) -> found = 0
    dut._log.info("Test 1: abcabc")
    test_str = "abcabc  "  # 8 chars, padded
    char_vals = [ord(c) for c in test_str]
    dut.char_array.value = sum([val * (2**8) ** i for i, val in enumerate(char_vals)])
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion
    for _ in range(100):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Test 1: Did not complete in time")
    
    if dut.found.value != 0:
        raise TestFailure(f"Test 1: Expected no unique char, but found={dut.found.value}, result={chr(int(dut.result.value))}")
    
    dut._log.info("Test 1 passed: No unique character found as expected")
    
    # Reset for next test
    dut.rst_n.value = 0
    await Timer(25, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test 2: "abc" -> 'a'
    dut._log.info("Test 2: abc")
    test_str = "abc     "  # 8 chars, padded
    char_vals = [ord(c) for c in test_str]
    dut.char_array.value = sum([val * (2**8) ** i for i, val in enumerate(char_vals)])
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(100):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Test 2: Did not complete in time")
    
    if dut.found.value != 1:
        raise TestFailure(f"Test 2: Expected unique char found, but found={dut.found.value}")
    
    if int(dut.result.value) != ord('a'):
        raise TestFailure(f"Test 2: Expected 'a' ({ord('a')}), got {chr(int(dut.result.value))} ({int(dut.result.value)})")
    
    dut._log.info("Test 2 passed: Found 'a' as expected")
    
    # Reset for next test
    dut.rst_n.value = 0
    await Timer(25, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test 3: "ababc" -> 'c'
    dut._log.info("Test 3: ababc")
    test_str = "ababc   "  # 8 chars, padded
    char_vals = [ord(c) for c in test_str]
    dut.char_array.value = sum([val * (2**8) ** i for i, val in enumerate(char_vals)])
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(100):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Test 3: Did not complete in time")
    
    if dut.found.value != 1:
        raise TestFailure(f"Test 3: Expected unique char found, but found={dut.found.value}")
    
    if int(dut.result.value) != ord('c'):
        raise TestFailure(f"Test 3: Expected 'c' ({ord('c')}), got {chr(int(dut.result.value))} ({int(dut.result.value)})")
    
    dut._log.info("Test 3 passed: Found 'c' as expected")
    
    # Additional edge case test: all same characters
    dut.rst_n.value = 0
    await Timer(25, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut._log.info("Test 4: aaaaaaaa")
    test_str = "aaaaaaaa"  # 8 chars
    char_vals = [ord(c) for c in test_str]
    dut.char_array.value = sum([val * (2**8) ** i for i, val in enumerate(char_vals)])
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(100):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Test 4: Did not complete in time")
    
    if dut.found.value != 0:
        raise TestFailure(f"Test 4: Expected no unique char, but found={dut.found.value}")
    
    dut._log.info("Test 4 passed: No unique character found as expected")
    
    # Additional test: single character
    dut.rst_n.value = 0
    await Timer(25, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut._log.info("Test 5: a       ")
    test_str = "a       "  # 8 chars
    char_vals = [ord(c) for c in test_str]
    dut.char_array.value = sum([val * (2**8) ** i for i, val in enumerate(char_vals)])
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(100):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    if dut.done.value != 1:
        raise TestFailure("Test 5: Did not complete in time")
    
    if dut.found.value != 1:
        raise TestFailure(f"Test 5: Expected unique char found, but found={dut.found.value}")
    
    if int(dut.result.value) != ord('a'):
        raise TestFailure(f"Test 5: Expected 'a' ({ord('a')}), got {chr(int(dut.result.value))} ({int(dut.result.value)})")
    
    dut._log.info("Test 5 passed: Found 'a' as expected")
    
    dut._log.info("All tests passed!")
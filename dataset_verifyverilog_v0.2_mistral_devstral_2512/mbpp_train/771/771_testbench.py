import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_balanced_parentheses(dut):
    """Test balanced parentheses checker with 8-character strings"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await Timer(10, units='ns')
    
    # Helper to set input string (8 chars, padded with spaces)
    def set_input(exp):
        exp = exp.ljust(8)[:8]  # Pad to 8 chars or truncate
        chars = [ord(c) for c in exp]
        dut.char_0.value = chars[0]
        dut.char_1.value = chars[1]
        dut.char_2.value = chars[2]
        dut.char_3.value = chars[3]
        dut.char_4.value = chars[4]
        dut.char_5.value = chars[5]
        dut.char_6.value = chars[6]
        dut.char_7.value = chars[7]
    
    # Helper to run test
    async def run_test(expression, expected):
        set_input(expression)
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (9 cycles max)
        for _ in range(10):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        
        result = bool(dut.balanced.value)
        dut._log.info(f"Expression: '{expression}' -> Balanced: {result} (Expected: {expected})")
        assert result == expected, f"Failed for '{expression}': got {result}, expected {expected}"
    
    # Test cases
    await run_test("{()}[{}]", True)   # Test 1
    await run_test("{()}[{]", False)   # Test 2
    await run_test("({})[][]", True)   # Test 3 (adapted to 8 chars)
    
    # Additional edge cases
    await run_test("()(){}[]", True)   # Multiple pairs
    await run_test("([)]", False)      # Incorrect nesting
    await run_test("(((()", False)     # Unmatched opening
    await run_test("))))", False)      # Unmatched closing
    await run_test("        ", True)   # All spaces (neutral)
    
    dut._log.info("All tests passed!")

import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_correct_bracketing(dut):
    """Test the correct_bracketing module with various bracket sequences"""
    
    # Create clock with 10ns period
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.brackets.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [
        # (input_string, expected_result, description)
        ("()", True, "Simple balanced"),
        ("(()())", True, "Nested balanced"),
        ("()()(()())()", True, "Complex balanced"),
        ("()()((()()())())(()()(()))", True, "Very complex balanced"),
        ("((()())))", False, "Extra closing bracket"),
        (")(()", False, "Starts with closing"),
        ("(", False, "Single opening"),
        ("(((", False, "Multiple opening"),
        (")", False, "Single closing"),
        ("(()", False, "Unclosed opening"),
        ("()()(()())())(()", False, "Extra closing in middle"),
        ("()()(()())()))()", False, "Extra closing at end"),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for test_str, expected, description in test_cases:
        # Convert string to 128-bit value
        # Each character is 8 bits, 16 positions
        val = 0
        for i, char in enumerate(test_str[:16]):
            val |= ord(char) << (8 * i)
        
        dut.brackets.value = val
        await RisingEdge(dut.clk)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done signal (max 18 cycles for safety)
        timeout = 20
        for _ in range(timeout):
            await RisingEdge(dut.clk)
            if dut.done.value:
                break
        
        # Check result
        actual = bool(dut.result.value)
        
        if actual == expected:
            passed += 1
            print(f"PASS: '{test_str}' -> {actual} (expected {expected})")
        else:
            print(f"FAIL: '{test_str}' -> {actual} (expected {expected}) - {description}")
        
        # Small delay between tests
        await Timer(50, units='ns')
    
    print(f"
Summary: {passed}/{total} tests passed")
    assert passed == total, f"Only {passed} out of {total} tests passed"

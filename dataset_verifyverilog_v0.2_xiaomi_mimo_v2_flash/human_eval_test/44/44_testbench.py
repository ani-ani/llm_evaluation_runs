import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

@cocotb.test()
async def test_change_base(dut):
    """Test change_base module with multiple test cases"""
    
    # Start clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.x.value = 0
    dut.base.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [
        (8, 3, "22"),
        (9, 3, "100"),
        (234, 2, "11101010"),
        (16, 2, "10000"),
        (8, 2, "1000"),
        (7, 2, "111"),
        (2, 3, "2"),
        (3, 4, "3"),
        (4, 5, "4"),
        (5, 6, "5"),
        (6, 7, "6"),
        (7, 8, "7"),
        (0, 2, "0"),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for x_val, base_val, expected_str in test_cases:
        # Convert expected string to packed format
        expected_result = 0
        for i, char in enumerate(expected_str):
            digit = int(char)
            expected_result |= digit << (4 * (len(expected_str) - 1 - i))
        expected_digits = len(expected_str)
        
        # Start computation
        dut.x.value = x_val
        dut.base.value = base_val
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done (max 16 cycles)
        max_cycles = 16
        for _ in range(max_cycles):
            if dut.done.value == 1:
                break
            await RisingEdge(dut.clk)
        
        # Check result
        if dut.done.value != 1:
            raise TestFailure(f"Test ({x_val}, {base_val}) timeout - done never went high")
        
        actual_result = int(dut.result.value)
        actual_digits = int(dut.num_digits.value)
        
        # Convert actual to string for comparison
        actual_str = ""
        for i in range(actual_digits):
            digit = (actual_result >> (4 * (actual_digits - 1 - i))) & 0xF
            actual_str += str(digit)
        
        if actual_str != expected_str:
            raise TestFailure(f"Test ({x_val}, {base_val}): expected '{expected_str}', got '{actual_str}'")
        
        print(f"Test ({x_val}, {base_val}): '{expected_str}' = '{actual_str}' ✓")
        passed += 1
        await RisingEdge(dut.clk)  # Small gap between tests
    
    print(f"
=== Results: {passed}/{total} tests passed ===")
    assert passed == total, f"Only {passed}/{total} tests passed"

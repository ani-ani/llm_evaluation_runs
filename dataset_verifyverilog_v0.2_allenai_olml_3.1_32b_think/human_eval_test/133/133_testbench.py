import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import numpy as np

# Helper function to convert float to Q16.16 format
def float_to_q16_16(value):
    return int(value * 65536) & 0xFFFFFFFF

# Helper function to convert Q16.16 to float
def q16_16_to_float(value):
    if value & 0x80000000:  # Negative number
        return -((~value + 1) / 65536.0)
    else:
        return value / 65536.0

@cocotb.test()
async def test_sum_squares(dut):
    """Test sum_squares module with various inputs"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.num_elements.value = 0
    for i in range(8):
        dut.input_list[i].value = 0
    
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [
        ([1, 2, 3], 14),
        ([1.0, 2, 3], 14),
        ([1, 3, 5, 7], 84),
        ([1.4, 4.2, 0], 29),
        ([-2.4, 1, 1], 6),
        ([100, 1, 15, 2], 10230),
        ([10000, 10000], 200000000),
        ([-1.4, 4.6, 6.3], 75),
        ([-1.4, 17.9, 18.9, 19.9], 1086),
        ([0], 0),
        ([-1], 1),
        ([-1, 1, 0], 2),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for lst, expected in test_cases:
        # Load inputs
        dut.num_elements.value = len(lst)
        for i in range(8):
            if i < len(lst):
                dut.input_list[i].value = float_to_q16_16(lst[i])
            else:
                dut.input_list[i].value = 0
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (max 15 cycles for safety)
        for _ in range(15):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        
        # Get result
        result_raw = int(dut.result.value)
        result_float = q16_16_to_float(result_raw)
        
        # Check
        try:
            assert abs(result_float - expected) < 0.01, f"Input {lst}: Expected {expected}, got {result_float}"
            passed += 1
            dut._log.info(f"PASS: {lst} -> {result_float} (expected {expected})")
        except AssertionError as e:
            dut._log.error(f"FAIL: {e}")
    
    print(f"
{passed}/{total} tests passed")
    assert passed == total, f"Only {passed}/{total} tests passed"
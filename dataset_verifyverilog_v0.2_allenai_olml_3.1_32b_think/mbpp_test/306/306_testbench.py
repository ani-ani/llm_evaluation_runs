import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

def to_fixed_point(value):
    """Convert decimal to Q16.16 fixed-point"""
    return int(value * 65536) & 0xFFFF

def from_fixed_point(value):
    """Convert Q16.16 fixed-point to decimal"""
    return value / 65536.0

@cocotb.test()
async def test_max_sum_increasing_subseq(dut):
    """Test max sum increasing subsequence with fixed array size 8"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.i_index.value = 0
    dut.k_index.value = 0
    for i in range(8):
        dut.a[i].value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test 1: a = [1, 101, 2, 3, 100, 4, 5], i=4, k=6, expected=11
    dut._log.info("Test 1: [1, 101, 2, 3, 100, 4, 5], i=4, k=6")
    a1 = [1, 101, 2, 3, 100, 4, 5]
    expected1 = 11
    for idx, val in enumerate(a1):
        dut.a[idx].value = to_fixed_point(val)
    for idx in range(7, 8):
        dut.a[idx].value = 0  # Pad remaining
    dut.i_index.value = 4
    dut.k_index.value = 6
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done (max 64 cycles)
    for _ in range(70):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    result_val = int(dut.result.value)
    result_decimal = from_fixed_point(result_val)
    dut._log.info(f"Result: {result_val} (Q16.16) = {result_decimal}")
    assert abs(result_decimal - expected1) < 0.01, f"Test 1 failed: expected {expected1}, got {result_decimal}"
    
    # Reset for next test
    dut.start.value = 0
    await RisingEdge(dut.clk)
    
    # Test 2: a = [1, 101, 2, 3, 100, 4, 5], i=2, k=5, expected=7
    dut._log.info("Test 2: [1, 101, 2, 3, 100, 4, 5], i=2, k=5")
    a2 = [1, 101, 2, 3, 100, 4, 5]
    expected2 = 7
    for idx, val in enumerate(a2):
        dut.a[idx].value = to_fixed_point(val)
    for idx in range(7, 8):
        dut.a[idx].value = 0
    dut.i_index.value = 2
    dut.k_index.value = 5
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(70):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    result_val = int(dut.result.value)
    result_decimal = from_fixed_point(result_val)
    dut._log.info(f"Result: {result_val} (Q16.16) = {result_decimal}")
    assert abs(result_decimal - expected2) < 0.01, f"Test 2 failed: expected {expected2}, got {result_decimal}"
    
    # Reset for next test
    dut.start.value = 0
    await RisingEdge(dut.clk)
    
    # Test 3: a = [11, 15, 19, 21, 26, 28, 31], i=2, k=4, expected=71
    dut._log.info("Test 3: [11, 15, 19, 21, 26, 28, 31], i=2, k=4")
    a3 = [11, 15, 19, 21, 26, 28, 31]
    expected3 = 71
    for idx, val in enumerate(a3):
        dut.a[idx].value = to_fixed_point(val)
    for idx in range(7, 8):
        dut.a[idx].value = 0
    dut.i_index.value = 2
    dut.k_index.value = 4
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(70):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    result_val = int(dut.result.value)
    result_decimal = from_fixed_point(result_val)
    dut._log.info(f"Result: {result_val} (Q16.16) = {result_decimal}")
    assert abs(result_decimal - expected3) < 0.01, f"Test 3 failed: expected {expected3}, got {result_decimal}"
    
    # Test 4: Edge case with smaller numbers
    dut._log.info("Test 4: [5, 3, 8, 6, 10], i=0, k=2, expected=13")
    a4 = [5, 3, 8, 6, 10]
    expected4 = 13
    for idx, val in enumerate(a4):
        dut.a[idx].value = to_fixed_point(val)
    for idx in range(5, 8):
        dut.a[idx].value = 0
    dut.i_index.value = 0
    dut.k_index.value = 2
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(70):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    result_val = int(dut.result.value)
    result_decimal = from_fixed_point(result_val)
    dut._log.info(f"Result: {result_val} (Q16.16) = {result_decimal}")
    assert abs(result_decimal - expected4) < 0.01, f"Test 4 failed: expected {expected4}, got {result_decimal}"
    
    # Test 5: Test with minimum valid indices
    dut._log.info("Test 5: [1, 5, 2, 3], i=1, k=3, expected=6")
    a5 = [1, 5, 2, 3]
    expected5 = 6
    for idx, val in enumerate(a5):
        dut.a[idx].value = to_fixed_point(val)
    for idx in range(4, 8):
        dut.a[idx].value = 0
    dut.i_index.value = 1
    dut.k_index.value = 3
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(70):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    result_val = int(dut.result.value)
    result_decimal = from_fixed_point(result_val)
    dut._log.info(f"Result: {result_val} (Q16.16) = {result_decimal}")
    assert abs(result_decimal - expected5) < 0.01, f"Test 5 failed: expected {expected5}, got {result_decimal}"
    
    dut._log.info("All tests passed!")
    dut._log.info("Summary: 5/5 tests passed")

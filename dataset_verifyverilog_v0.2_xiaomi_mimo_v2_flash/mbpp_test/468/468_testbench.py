import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_max_product_seq(dut):
    """Test max_product_seq module with multiple test cases"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.arr_len.value = 0
    dut.arr_0.value = 0
    dut.arr_1.value = 0
    dut.arr_2.value = 0
    dut.arr_3.value = 0
    dut.arr_4.value = 0
    dut.arr_5.value = 0
    dut.arr_6.value = 0
    dut.arr_7.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: [3, 100, 4, 5, 150, 6] -> 3000
    dut.arr_len.value = 6
    dut.arr_0.value = 3
    dut.arr_1.value = 100
    dut.arr_2.value = 4
    dut.arr_3.value = 5
    dut.arr_4.value = 150
    dut.arr_5.value = 6
    dut.arr_6.value = 0
    dut.arr_7.value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion
    timeout = 0
    while not dut.done.value and timeout < 300:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert timeout < 300, "Timeout: computation did not finish"
    assert dut.result.value == 3000, f"Test 1 failed: expected 3000, got {dut.result.value}"
    print(f"Test 1 passed: result = {dut.result.value}")
    
    # Wait a few cycles before next test
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 2: [4, 42, 55, 68, 80] -> 50265600
    dut.arr_len.value = 5
    dut.arr_0.value = 4
    dut.arr_1.value = 42
    dut.arr_2.value = 55
    dut.arr_3.value = 68
    dut.arr_4.value = 80
    dut.arr_5.value = 0
    dut.arr_6.value = 0
    dut.arr_7.value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 300:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert timeout < 300, "Timeout: computation did not finish"
    assert dut.result.value == 50265600, f"Test 2 failed: expected 50265600, got {dut.result.value}"
    print(f"Test 2 passed: result = {dut.result.value}")
    
    # Wait before next test
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 3: [10, 22, 9, 33, 21, 50, 41, 60] -> 2460
    dut.arr_len.value = 8
    dut.arr_0.value = 10
    dut.arr_1.value = 22
    dut.arr_2.value = 9
    dut.arr_3.value = 33
    dut.arr_4.value = 21
    dut.arr_5.value = 50
    dut.arr_6.value = 41
    dut.arr_7.value = 60
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 300:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert timeout < 300, "Timeout: computation did not finish"
    assert dut.result.value == 2460, f"Test 3 failed: expected 2460, got {dut.result.value}"
    print(f"Test 3 passed: result = {dut.result.value}")
    
    # Wait before next test
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Edge case 4: single element array [7] -> 7
    dut.arr_len.value = 1
    dut.arr_0.value = 7
    dut.arr_1.value = 0
    dut.arr_2.value = 0
    dut.arr_3.value = 0
    dut.arr_4.value = 0
    dut.arr_5.value = 0
    dut.arr_6.value = 0
    dut.arr_7.value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 300:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert timeout < 300, "Timeout: computation did not finish"
    assert dut.result.value == 7, f"Edge case failed: expected 7, got {dut.result.value}"
    print(f"Edge case passed: result = {dut.result.value}")
    
    # Wait before next test
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Edge case 5: decreasing array [8, 7, 6, 5] -> 8
    dut.arr_len.value = 4
    dut.arr_0.value = 8
    dut.arr_1.value = 7
    dut.arr_2.value = 6
    dut.arr_3.value = 5
    dut.arr_4.value = 0
    dut.arr_5.value = 0
    dut.arr_6.value = 0
    dut.arr_7.value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 300:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert timeout < 300, "Timeout: computation did not finish"
    assert dut.result.value == 8, f"Edge case failed: expected 8, got {dut.result.value}"
    print(f"Edge case passed: result = {dut.result.value}")
    
    print("
=== All 5 tests passed ===")

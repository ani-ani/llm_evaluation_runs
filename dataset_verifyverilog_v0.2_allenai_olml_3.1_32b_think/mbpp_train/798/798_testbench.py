import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_array_sum(dut):
    """Test array sum module with various test cases"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Initialize inputs
    dut.rst_n.value = 1
    dut.start.value = 0
    dut.array_length.value = 0
    for i in range(8):
        setattr(dut, f'array_data[{i}]', 0)
    
    # Reset sequence
    await Timer(20, units='ns')
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: [1, 2, 3] = 6
    dut.array_length.value = 3
    dut.array_data[0].value = 1
    dut.array_data[1].value = 2
    dut.array_data[2].value = 3
    dut.array_data[3].value = 0
    dut.array_data[4].value = 0
    dut.array_data[5].value = 0
    dut.array_data[6].value = 0
    dut.array_data[7].value = 0
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion
    for _ in range(12):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    assert dut.done.value == 1, "Done signal should be high"
    assert dut.result.value == 6, f"Expected 6, got {dut.result.value}"
    print(f"Test 1 passed: [1,2,3] = {dut.result.value}")
    
    # Reset for next test
    dut.start.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 2: [15, 12, 13, 10] = 50
    dut.array_length.value = 4
    dut.array_data[0].value = 15
    dut.array_data[1].value = 12
    dut.array_data[2].value = 13
    dut.array_data[3].value = 10
    dut.array_data[4].value = 0
    dut.array_data[5].value = 0
    dut.array_data[6].value = 0
    dut.array_data[7].value = 0
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(12):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    assert dut.done.value == 1, "Done signal should be high"
    assert dut.result.value == 50, f"Expected 50, got {dut.result.value}"
    print(f"Test 2 passed: [15,12,13,10] = {dut.result.value}")
    
    # Reset for next test
    dut.start.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 3: [0, 1, 2] = 3
    dut.array_length.value = 3
    dut.array_data[0].value = 0
    dut.array_data[1].value = 1
    dut.array_data[2].value = 2
    dut.array_data[3].value = 0
    dut.array_data[4].value = 0
    dut.array_data[5].value = 0
    dut.array_data[6].value = 0
    dut.array_data[7].value = 0
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(12):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    assert dut.done.value == 1, "Done signal should be high"
    assert dut.result.value == 3, f"Expected 3, got {dut.result.value}"
    print(f"Test 3 passed: [0,1,2] = {dut.result.value}")
    
    # Reset for next test
    dut.start.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Edge case: Maximum array (8 elements)
    dut.array_length.value = 0  # 000 means 8 elements in our encoding
    dut.array_data[0].value = 255
    dut.array_data[1].value = 255
    dut.array_data[2].value = 255
    dut.array_data[3].value = 255
    dut.array_data[4].value = 255
    dut.array_data[5].value = 255
    dut.array_data[6].value = 255
    dut.array_data[7].value = 255
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(12):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    assert dut.done.value == 1, "Done signal should be high"
    expected_max = 8 * 255  # 2040
    assert dut.result.value == expected_max, f"Expected {expected_max}, got {dut.result.value}"
    print(f"Test 4 passed: 8×255 = {dut.result.value}")
    
    # Reset for next test
    dut.start.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Edge case: Single element
    dut.array_length.value = 1  # 001 means 1 element
    dut.array_data[0].value = 42
    dut.array_data[1].value = 0
    dut.array_data[2].value = 0
    dut.array_data[3].value = 0
    dut.array_data[4].value = 0
    dut.array_data[5].value = 0
    dut.array_data[6].value = 0
    dut.array_data[7].value = 0
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(12):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    assert dut.done.value == 1, "Done signal should be high"
    assert dut.result.value == 42, f"Expected 42, got {dut.result.value}"
    print(f"Test 5 passed: [42] = {dut.result.value}")
    
    print("
All 5 tests passed!")
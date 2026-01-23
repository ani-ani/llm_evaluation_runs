import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_envelope_optimizer(dut):
    """Test the envelope optimizer module"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: 5 cards, 1 envelope type
    dut.card_width.value = [10, 9, 4, 12, 2]
    dut.card_height.value = [10, 8, 12, 4, 3]
    dut.card_qty.value = [5, 10, 20, 8, 16]
    dut.k_envelopes.value = 1
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion (should take ~832 cycles)
    timeout = 1000
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    else:
        raise TimeoutError("Module did not complete in time")
    
    result = int(dut.min_waste.value)
    expected = 5836
    assert result == expected, f"Test 1 failed: got {result}, expected {expected}"
    print(f"Test 1 passed: {result} == {expected}")
    
    # Test case 2: 5 cards, 2 envelope types
    await RisingEdge(dut.clk)
    dut.start.value = 1
    dut.k_envelopes.value = 2
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 1000
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    else:
        raise TimeoutError("Module did not complete in time")
    
    result = int(dut.min_waste.value)
    expected = 1828
    assert result == expected, f"Test 2 failed: got {result}, expected {expected}"
    print(f"Test 2 passed: {result} == {expected}")
    
    # Test case 3: 5 cards, 5 envelope types
    await RisingEdge(dut.clk)
    dut.start.value = 1
    dut.k_envelopes.value = 5
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 1000
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    else:
        raise TimeoutError("Module did not complete in time")
    
    result = int(dut.min_waste.value)
    expected = 0
    assert result == expected, f"Test 3 failed: got {result}, expected {expected}"
    print(f"Test 3 passed: {result} == {expected}")
    
    # Edge case: single card type
    await RisingEdge(dut.clk)
    dut.card_width.value = [100, 0, 0, 0, 0]
    dut.card_height.value = [200, 0, 0, 0, 0]
    dut.card_qty.value = [1, 0, 0, 0, 0]
    dut.k_envelopes.value = 1
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 1000
    for _ in range(timeout):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    result = int(dut.min_waste.value)
    expected = 0
    assert result == expected, f"Edge case failed: got {result}, expected {expected}"
    print(f"Edge case passed: {result} == {expected}")
    
    print("All tests passed!")
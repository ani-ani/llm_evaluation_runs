import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_find_remainder(dut):
    """Test find_remainder module with various cases"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    dut.arr_len.value = 0
    for i in range(8):
        dut.arr[i].value = 0
    
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    tests_passed = 0
    tests_total = 3
    
    # Test 1: [100, 10, 5, 25, 35, 14] % 11 = 9
    dut.n.value = 11
    dut.arr_len.value = 6
    dut.arr[0].value = 100
    dut.arr[1].value = 10
    dut.arr[2].value = 5
    dut.arr[3].value = 25
    dut.arr[4].value = 35
    dut.arr[5].value = 14
    dut.arr[6].value = 0
    dut.arr[7].value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    assert dut.result.value == 9, f"Test 1 failed: expected 9, got {dut.result.value}"
    print(f"Test 1 passed: result = {dut.result.value}")
    tests_passed += 1
    
    await RisingEdge(dut.clk)
    
    # Test 2: [1, 1, 1] % 1 = 0
    dut.n.value = 1
    dut.arr_len.value = 3
    dut.arr[0].value = 1
    dut.arr[1].value = 1
    dut.arr[2].value = 1
    dut.arr[3].value = 0
    dut.arr[4].value = 0
    dut.arr[5].value = 0
    dut.arr[6].value = 0
    dut.arr[7].value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    assert dut.result.value == 0, f"Test 2 failed: expected 0, got {dut.result.value}"
    print(f"Test 2 passed: result = {dut.result.value}")
    tests_passed += 1
    
    await RisingEdge(dut.clk)
    
    # Test 3: [1, 2, 1] % 2 = 0
    dut.n.value = 2
    dut.arr_len.value = 3
    dut.arr[0].value = 1
    dut.arr[1].value = 2
    dut.arr[2].value = 1
    dut.arr[3].value = 0
    dut.arr[4].value = 0
    dut.arr[5].value = 0
    dut.arr[6].value = 0
    dut.arr[7].value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while not dut.done.value:
        await RisingEdge(dut.clk)
    
    assert dut.result.value == 0, f"Test 3 failed: expected 0, got {dut.result.value}"
    print(f"Test 3 passed: result = {dut.result.value}")
    tests_passed += 1
    
    print(f"
Summary: {tests_passed}/{tests_total} tests passed")

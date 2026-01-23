import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_kth_element(dut):
    """Test kth_element module with multiple test cases"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.k.value = 0
    dut.arr_0.value = 0
    dut.arr_1.value = 0
    dut.arr_2.value = 0
    dut.arr_3.value = 0
    dut.arr_4.value = 0
    dut.arr_5.value = 0
    dut.arr_6.value = 0
    dut.arr_7.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: arr=[12,3,5,7,19], k=2, expected=3
    dut.arr_0.value = 12
    dut.arr_1.value = 3
    dut.arr_2.value = 5
    dut.arr_3.value = 7
    dut.arr_4.value = 19
    dut.arr_5.value = 0
    dut.arr_6.value = 0
    dut.arr_7.value = 0
    dut.k.value = 2
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done signal
    timeout = 100
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    if dut.done.value != 1:
        raise TestFailure(f"Test 1: Done signal not asserted after {timeout} cycles")
    
    if dut.result.value != 3:
        raise TestFailure(f"Test 1: Expected 3, got {int(dut.result.value)}")
    
    print("Test 1 passed: k=2, result=3")
    await RisingEdge(dut.clk)
    
    # Test case 2: arr=[17,24,8,23], k=3, expected=8
    dut.arr_0.value = 17
    dut.arr_1.value = 24
    dut.arr_2.value = 8
    dut.arr_3.value = 23
    dut.arr_4.value = 0
    dut.arr_5.value = 0
    dut.arr_6.value = 0
    dut.arr_7.value = 0
    dut.k.value = 3
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 100
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    if dut.done.value != 1:
        raise TestFailure(f"Test 2: Done signal not asserted after {timeout} cycles")
    
    if dut.result.value != 8:
        raise TestFailure(f"Test 2: Expected 8, got {int(dut.result.value)}")
    
    print("Test 2 passed: k=3, result=8")
    await RisingEdge(dut.clk)
    
    # Test case 3: arr=[16,21,25,36,4], k=4, expected=36
    dut.arr_0.value = 16
    dut.arr_1.value = 21
    dut.arr_2.value = 25
    dut.arr_3.value = 36
    dut.arr_4.value = 4
    dut.arr_5.value = 0
    dut.arr_6.value = 0
    dut.arr_7.value = 0
    dut.k.value = 4
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 100
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    if dut.done.value != 1:
        raise TestFailure(f"Test 3: Done signal not asserted after {timeout} cycles")
    
    if dut.result.value != 36:
        raise TestFailure(f"Test 3: Expected 36, got {int(dut.result.value)}")
    
    print("Test 3 passed: k=4, result=36")
    await RisingEdge(dut.clk)
    
    # Test case 4: edge case, k=1 (minimum)
    dut.arr_0.value = 9
    dut.arr_1.value = 3
    dut.arr_2.value = 7
    dut.arr_3.value = 1
    dut.arr_4.value = 5
    dut.arr_5.value = 0
    dut.arr_6.value = 0
    dut.arr_7.value = 0
    dut.k.value = 1
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 100
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    if dut.done.value != 1:
        raise TestFailure(f"Test 4: Done signal not asserted after {timeout} cycles")
    
    if dut.result.value != 1:
        raise TestFailure(f"Test 4: Expected 1, got {int(dut.result.value)}")
    
    print("Test 4 passed: k=1, result=1 (minimum)")
    await RisingEdge(dut.clk)
    
    # Test case 5: edge case, k=8 (maximum, with zeros)
    dut.arr_0.value = 2
    dut.arr_1.value = 8
    dut.arr_2.value = 1
    dut.arr_3.value = 5
    dut.arr_4.value = 3
    dut.arr_5.value = 7
    dut.arr_6.value = 4
    dut.arr_7.value = 6
    dut.k.value = 8
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 100
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    
    if dut.done.value != 1:
        raise TestFailure(f"Test 5: Done signal not asserted after {timeout} cycles")
    
    if dut.result.value != 8:
        raise TestFailure(f"Test 5: Expected 8, got {int(dut.result.value)}")
    
    print("Test 5 passed: k=8, result=8 (maximum)")
    print("All 5 tests passed!")
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_reverse_array_upto_k(dut):
    """Test reverse_array_upto_k module with multiple test cases"""
    
    # Create clock (10ns period)
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset the DUT
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.k.value = 0
    for i in range(8):
        dut.arr_in[i].value = 0
    
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: k=4, input=[1,2,3,4,5,6,7,8]
    dut.arr_in[0].value = 1
    dut.arr_in[1].value = 2
    dut.arr_in[2].value = 3
    dut.arr_in[3].value = 4
    dut.arr_in[4].value = 5
    dut.arr_in[5].value = 6
    dut.arr_in[6].value = 7
    dut.arr_in[7].value = 8
    dut.k.value = 4
    
    # Start computation
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done (up to 25 cycles)
    for _ in range(25):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    # Check result: [4,3,2,1,5,6,7,8]
    expected = [4,3,2,1,5,6,7,8]
    for i in range(8):
        actual = int(dut.arr_out[i].value)
        if actual != expected[i]:
            raise TestFailure(f"Test 1 failed at index {i}: expected {expected[i]}, got {actual}")
    
    print("Test 1 passed: reverse first 4 elements")
    
    # Test case 2: k=2, input=[4,5,6,7,0,0,0,0]
    dut.arr_in[0].value = 4
    dut.arr_in[1].value = 5
    dut.arr_in[2].value = 6
    dut.arr_in[3].value = 7
    dut.arr_in[4].value = 0
    dut.arr_in[5].value = 0
    dut.arr_in[6].value = 0
    dut.arr_in[7].value = 0
    dut.k.value = 2
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(25):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    expected = [5,4,6,7,0,0,0,0]
    for i in range(8):
        actual = int(dut.arr_out[i].value)
        if actual != expected[i]:
            raise TestFailure(f"Test 2 failed at index {i}: expected {expected[i]}, got {actual}")
    
    print("Test 2 passed: reverse first 2 elements")
    
    # Test case 3: k=3, input=[9,8,7,6,5,0,0,0]
    dut.arr_in[0].value = 9
    dut.arr_in[1].value = 8
    dut.arr_in[2].value = 7
    dut.arr_in[3].value = 6
    dut.arr_in[4].value = 5
    dut.arr_in[5].value = 0
    dut.arr_in[6].value = 0
    dut.arr_in[7].value = 0
    dut.k.value = 3
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(25):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    expected = [7,8,9,6,5,0,0,0]
    for i in range(8):
        actual = int(dut.arr_out[i].value)
        if actual != expected[i]:
            raise TestFailure(f"Test 3 failed at index {i}: expected {expected[i]}, got {actual}")
    
    print("Test 3 passed: reverse first 3 elements")
    
    # Edge case: k=1 (reverse first element only - should be unchanged)
    dut.arr_in[0].value = 10
    dut.arr_in[1].value = 20
    dut.arr_in[2].value = 30
    dut.arr_in[3].value = 40
    dut.arr_in[4].value = 0
    dut.arr_in[5].value = 0
    dut.arr_in[6].value = 0
    dut.arr_in[7].value = 0
    dut.k.value = 1
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(25):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    expected = [10,20,30,40,0,0,0,0]
    for i in range(8):
        actual = int(dut.arr_out[i].value)
        if actual != expected[i]:
            raise TestFailure(f"Edge test failed at index {i}: expected {expected[i]}, got {actual}")
    
    print("Edge test passed: k=1 (no change)")
    
    # Edge case: k=8 (reverse entire array)
    dut.arr_in[0].value = 1
    dut.arr_in[1].value = 2
    dut.arr_in[2].value = 3
    dut.arr_in[3].value = 4
    dut.arr_in[4].value = 5
    dut.arr_in[5].value = 6
    dut.arr_in[6].value = 7
    dut.arr_in[7].value = 8
    dut.k.value = 8
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(25):
        await RisingEdge(dut.clk)
        if dut.done.value == 1:
            break
    
    expected = [8,7,6,5,4,3,2,1]
    for i in range(8):
        actual = int(dut.arr_out[i].value)
        if actual != expected[i]:
            raise TestFailure(f"Edge test failed at index {i}: expected {expected[i]}, got {actual}")
    
    print("Edge test passed: k=8 (full reverse)")
    print("All 5/5 tests passed!")
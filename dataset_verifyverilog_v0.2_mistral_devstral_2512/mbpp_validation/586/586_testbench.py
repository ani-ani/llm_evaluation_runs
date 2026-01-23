import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock

@cocotb.test()
async def test_array_rotator(dut):
    """Test array rotation functionality"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    for i in range(8):
        dut.arr[i].value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: n=2
    dut.arr[0].value = 12
    dut.arr[1].value = 10
    dut.arr[2].value = 5
    dut.arr[3].value = 6
    dut.arr[4].value = 52
    dut.arr[5].value = 36
    dut.arr[6].value = 0
    dut.arr[7].value = 1
    dut.n.value = 2
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    await RisingEdge(dut.clk)
    
    # Check result
    expected = [5,6,52,36,0,1,12,10]
    actual = [int(dut.result[i].value) for i in range(8)]
    assert actual == expected, f"Test 1 failed: expected {expected}, got {actual}"
    print("Test 1 passed")
    
    # Test case 2: n=1
    dut.arr[0].value = 1
    dut.arr[1].value = 2
    dut.arr[2].value = 3
    dut.arr[3].value = 4
    dut.arr[4].value = 0
    dut.arr[5].value = 0
    dut.arr[6].value = 0
    dut.arr[7].value = 0
    dut.n.value = 1
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    await RisingEdge(dut.clk)
    
    expected = [2,3,4,0,0,0,0,1]
    actual = [int(dut.result[i].value) for i in range(8)]
    assert actual == expected, f"Test 2 failed: expected {expected}, got {actual}"
    print("Test 2 passed")
    
    # Test case 3: n=3
    dut.arr[0].value = 0
    dut.arr[1].value = 1
    dut.arr[2].value = 2
    dut.arr[3].value = 3
    dut.arr[4].value = 4
    dut.arr[5].value = 5
    dut.arr[6].value = 6
    dut.arr[7].value = 7
    dut.n.value = 3
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    await RisingEdge(dut.clk)
    
    expected = [3,4,5,6,7,0,1,2]
    actual = [int(dut.result[i].value) for i in range(8)]
    assert actual == expected, f"Test 3 failed: expected {expected}, got {actual}"
    print("Test 3 passed")
    
    # Test case 4: n=0 (no rotation)
    dut.arr[0].value = 10
    dut.arr[1].value = 20
    dut.arr[2].value = 30
    dut.arr[3].value = 40
    dut.arr[4].value = 50
    dut.arr[5].value = 60
    dut.arr[6].value = 70
    dut.arr[7].value = 80
    dut.n.value = 0
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    await RisingEdge(dut.clk)
    
    expected = [10,20,30,40,50,60,70,80]
    actual = [int(dut.result[i].value) for i in range(8)]
    assert actual == expected, f"Test 4 failed: expected {expected}, got {actual}"
    print("Test 4 passed")
    
    # Test case 5: n=7 (last element to front)
    dut.arr[0].value = 1
    dut.arr[1].value = 2
    dut.arr[2].value = 3
    dut.arr[3].value = 4
    dut.arr[4].value = 5
    dut.arr[5].value = 6
    dut.arr[6].value = 7
    dut.arr[7].value = 8
    dut.n.value = 7
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    await RisingEdge(dut.clk)
    
    expected = [8,1,2,3,4,5,6,7]
    actual = [int(dut.result[i].value) for i in range(8)]
    assert actual == expected, f"Test 5 failed: expected {expected}, got {actual}"
    print("Test 5 passed")
    
    print("5/5 tests passed")
import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

@cocotb.test()
async def test_triple_sum_counter(dut):
    """Test triple sum counter with various cases"""
    # Initialize
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    for i in range(8):
        dut.arr[i].value = 0
    
    # Start clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    # Test case 1: N=4, [1,2,3,4] -> 4
    dut.n.value = 4
    dut.arr[0].value = 1
    dut.arr[1].value = 2
    dut.arr[2].value = 3
    dut.arr[3].value = 4
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion
    timeout = 200
    cycles = 0
    while not dut.done.value and cycles < timeout:
        await RisingEdge(dut.clk)
        cycles += 1
    
    if cycles >= timeout:
        raise TestFailure("Timeout waiting for done signal")
    
    result = int(dut.count.value)
    print(f"Test 1: N=4, arr=[1,2,3,4]")
    print(f"Expected: 4, Got: {result}")
    assert result == 4, f"Test 1 failed: expected 4, got {result}"
    
    # Test case 2: N=6, [1,1,3,3,4,6] -> 10
    await Timer(100, units='ns')
    dut.rst_n.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    dut.n.value = 6
    dut.arr[0].value = 1
    dut.arr[1].value = 1
    dut.arr[2].value = 3
    dut.arr[3].value = 3
    dut.arr[4].value = 4
    dut.arr[5].value = 6
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    cycles = 0
    while not dut.done.value and cycles < timeout:
        await RisingEdge(dut.clk)
        cycles += 1
    
    if cycles >= timeout:
        raise TestFailure("Timeout waiting for done signal")
    
    result = int(dut.count.value)
    print(f"Test 2: N=6, arr=[1,1,3,3,4,6]")
    print(f"Expected: 10, Got: {result}")
    assert result == 10, f"Test 2 failed: expected 10, got {result}"
    
    # Test case 3: N=3, [0,0,0] -> 6 (all zeros, 3*2*1 = 6 permutations)
    await Timer(100, units='ns')
    dut.rst_n.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    dut.n.value = 3
    dut.arr[0].value = 0
    dut.arr[1].value = 0
    dut.arr[2].value = 0
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    cycles = 0
    while not dut.done.value and cycles < timeout:
        await RisingEdge(dut.clk)
        cycles += 1
    
    if cycles >= timeout:
        raise TestFailure("Timeout waiting for done signal")
    
    result = int(dut.count.value)
    print(f"Test 3: N=3, arr=[0,0,0]")
    print(f"Expected: 6, Got: {result}")
    assert result == 6, f"Test 3 failed: expected 6, got {result}"
    
    # Test case 4: N=5, [-1,0,1,2,3] -> 4
    await Timer(100, units='ns')
    dut.rst_n.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    dut.n.value = 5
    dut.arr[0].value = 65535  # -1 in 2's complement 16-bit
    dut.arr[1].value = 0
    dut.arr[2].value = 1
    dut.arr[3].value = 2
    dut.arr[4].value = 3
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    cycles = 0
    while not dut.done.value and cycles < timeout:
        await RisingEdge(dut.clk)
        cycles += 1
    
    if cycles >= timeout:
        raise TestFailure("Timeout waiting for done signal")
    
    result = int(dut.count.value)
    print(f"Test 4: N=5, arr=[-1,0,1,2,3]")
    print(f"Expected: 4, Got: {result}")
    assert result == 4, f"Test 4 failed: expected 4, got {result}"
    
    # Test case 5: N=2, [1,2] -> 0 (not enough elements)
    await Timer(100, units='ns')
    dut.rst_n.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    dut.n.value = 2
    dut.arr[0].value = 1
    dut.arr[1].value = 2
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    cycles = 0
    while not dut.done.value and cycles < timeout:
        await RisingEdge(dut.clk)
        cycles += 1
    
    if cycles >= timeout:
        raise TestFailure("Timeout waiting for done signal")
    
    result = int(dut.count.value)
    print(f"Test 5: N=2, arr=[1,2]")
    print(f"Expected: 0, Got: {result}")
    assert result == 0, f"Test 5 failed: expected 0, got {result}"
    
    print("
All tests passed!")
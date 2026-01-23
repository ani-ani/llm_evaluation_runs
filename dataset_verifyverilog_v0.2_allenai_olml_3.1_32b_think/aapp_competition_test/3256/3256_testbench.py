import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

@cocotb.test()
async def test_bits_game(dut):
    """Test Bits Game module with multiple test cases"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.N.value = 0
    dut.K.value = 0
    for i in range(16):
        dut.A[i].value = 0
    
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: N=4, K=2, A=[2,3,4,1], expected=3
    dut.N.value = 4
    dut.K.value = 2
    dut.A[0].value = 2
    dut.A[1].value = 3
    dut.A[2].value = 4
    dut.A[3].value = 1
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion
    timeout = 0
    while not dut.done.value and timeout < 1000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 1000:
        raise TestFailure("Test case 1 timed out")
    
    result = int(dut.result.value)
    print(f"Test 1: N=4, K=2, A=[2,3,4,1]")
    print(f"  Expected: 3, Got: {result}")
    assert result == 3, f"Test 1 failed: expected 3, got {result}"
    
    # Reset for next test
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 2: N=6, K=3, A=[2,2,2,4,4,4], expected=4
    dut.N.value = 6
    dut.K.value = 3
    dut.A[0].value = 2
    dut.A[1].value = 2
    dut.A[2].value = 2
    dut.A[3].value = 4
    dut.A[4].value = 4
    dut.A[5].value = 4
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 1000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 1000:
        raise TestFailure("Test case 2 timed out")
    
    result = int(dut.result.value)
    print(f"Test 2: N=6, K=3, A=[2,2,2,4,4,4]")
    print(f"  Expected: 4, Got: {result}")
    assert result == 4, f"Test 2 failed: expected 4, got {result}"
    
    # Reset for next test
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 3: N=4, K=1, A=[0,1,2,3], expected=3
    dut.N.value = 4
    dut.K.value = 1
    dut.A[0].value = 0
    dut.A[1].value = 1
    dut.A[2].value = 2
    dut.A[3].value = 3
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 1000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 1000:
        raise TestFailure("Test case 3 timed out")
    
    result = int(dut.result.value)
    print(f"Test 3: N=4, K=1, A=[0,1,2,3]")
    print(f"  Expected: 3, Got: {result}")
    assert result == 3, f"Test 3 failed: expected 3, got {result}"
    
    # Additional test: N=5, K=3, A=[7,7,7,7,7], expected=7
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.N.value = 5
    dut.K.value = 3
    for i in range(5):
        dut.A[i].value = 7
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 1000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 1000:
        raise TestFailure("Test case 4 timed out")
    
    result = int(dut.result.value)
    print(f"Test 4: N=5, K=3, A=[7,7,7,7,7]")
    print(f"  Expected: 7, Got: {result}")
    assert result == 7, f"Test 4 failed: expected 7, got {result}"
    
    print("
=== Summary: All 4 tests passed! ===")

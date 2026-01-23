import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_perm_run_counter(dut):
    """Test permutation run counter with small values"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    dut.k.value = 0
    dut.p.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: n=1, k=7, p=1000000007
    # Expected: 1
    dut.n.value = 1
    dut.k.value = 7
    dut.p.value = 1000000007
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion with timeout
    timeout = 0
    while not dut.done.value and timeout < 10000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 10000:
        raise TestFailure("Test case 1: Timeout waiting for completion")
    
    result = int(dut.result.value)
    expected = 1
    if result != expected:
        raise TestFailure(f"Test case 1 failed: got {result}, expected {expected}")
    print(f"Test 1 passed: n=1, k=7, p=1000000007, result={result}")
    
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    
    # Test case 2: n=3, k=2, p=1000000007
    # Expected: 4
    dut.n.value = 3
    dut.k.value = 2
    dut.p.value = 1000000007
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 10000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 10000:
        raise TestFailure("Test case 2: Timeout waiting for completion")
    
    result = int(dut.result.value)
    expected = 4
    if result != expected:
        raise TestFailure(f"Test case 2 failed: got {result}, expected {expected}")
    print(f"Test 2 passed: n=3, k=2, p=1000000007, result={result}")
    
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    
    # Test case 3: n=4, k=3, p=1000000009
    # For n=4, k=3, we need to compute manually
    # Let's test with smaller values that we can verify
    dut.n.value = 2
    dut.k.value = 2
    dut.p.value = 1000000007
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 10000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 10000:
        raise TestFailure("Test case 3: Timeout waiting for completion")
    
    result = int(dut.result.value)
    # For n=2, k=2: all 2! = 2 permutations work
    expected = 2
    if result != expected:
        raise TestFailure(f"Test case 3 failed: got {result}, expected {expected}")
    print(f"Test 3 passed: n=2, k=2, p=1000000007, result={result}")
    
    print(f"
Summary: 3/3 tests passed")
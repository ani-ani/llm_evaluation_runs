import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_max_ranks_basic(dut):
    """Test basic case with 2 assistants, no forced constraints"""
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    # Test case: N=2, K=10, a=[1,5], b=[1,4]
    # Expected: 2 ranks (no forced constraints)
    dut.n.value = 2
    dut.k.value = 10
    dut.a[0].value = 1
    dut.a[1].value = 5
    dut.b[0].value = 1
    dut.b[1].value = 4
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion
    timeout = 0
    while not dut.done.value and timeout < 300:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 300:
        raise TestFailure("Timeout waiting for done signal")
    
    result = int(dut.result.value)
    dut._log.info(f"Test 1 - Result: {result}, Expected: 2")
    assert result == 2, f"Expected 2, got {result}"

@cocotb.test()
async def test_max_ranks_forced(dut):
    """Test case with forced constraint"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    # Test case: N=2, K=10, a=[1,12], b=[13,1]
    # 1+10 < 12 => true, so rank(1) >= rank(0)
    # 1+10 < 13? No. 1+10 < 1? No.
    # So only one direction: 1 >= 0
    # But need to check both directions: 0+10 < 12? No, 0+10 < 13? Yes => rank(0) >= rank(1)
    # Wait: a[0]=1, a[1]=12, K=10 => 1+10 < 12? 11 < 12 => true => rank(1) >= rank(0)
    # b[0]=13, b[1]=1 => 13+10 < 1? No. 1+10 < 13? 11 < 13 => true => rank(0) >= rank(1)
    # So both directions forced: rank(0) >= rank(1) AND rank(1) >= rank(0)
    # Therefore they must have same rank, so max ranks = 1
    dut.n.value = 2
    dut.k.value = 10
    dut.a[0].value = 1
    dut.a[1].value = 12
    dut.b[0].value = 13
    dut.b[1].value = 1
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 300:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 300:
        raise TestFailure("Timeout")
    
    result = int(dut.result.value)
    dut._log.info(f"Test 2 - Result: {result}, Expected: 1")
    assert result == 1, f"Expected 1, got {result}"

@cocotb.test()
async def test_max_ranks_three_nodes(dut):
    """Test with 3 nodes forming chain"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    # N=3, K=5
    # a=[1,6,11], b=[20,20,20]
    # 1+5 < 6 => true => rank(1) >= rank(0)
    # 6+5 < 11 => true => rank(2) >= rank(1)
    # No reverse constraints
    # Result should be 3 ranks
    dut.n.value = 3
    dut.k.value = 5
    dut.a[0].value = 1
    dut.a[1].value = 6
    dut.a[2].value = 11
    dut.b[0].value = 20
    dut.b[1].value = 20
    dut.b[2].value = 20
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 300:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 300:
        raise TestFailure("Timeout")
    
    result = int(dut.result.value)
    dut._log.info(f"Test 3 - Result: {result}, Expected: 3")
    assert result == 3, f"Expected 3, got {result}"

@cocotb.test()
async def test_max_ranks_single_node(dut):
    """Test with single node"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    dut.n.value = 1
    dut.k.value = 10
    dut.a[0].value = 5
    dut.b[0].value = 5
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 300:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 300:
        raise TestFailure("Timeout")
    
    result = int(dut.result.value)
    dut._log.info(f"Test 4 - Result: {result}, Expected: 1")
    assert result == 1, f"Expected 1, got {result}"

@cocotb.test()
async def test_max_ranks_equal_values(dut):
    """Test with equal values"""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    # N=2, K=10, a=[5,5], b=[5,5]
    # 5+10 < 5? No. 5+10 < 5? No.
    # No constraints, 2 ranks
    dut.n.value = 2
    dut.k.value = 10
    dut.a[0].value = 5
    dut.a[1].value = 5
    dut.b[0].value = 5
    dut.b[1].value = 5
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 300:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 300:
        raise TestFailure("Timeout")
    
    result = int(dut.result.value)
    dut._log.info(f"Test 5 - Result: {result}, Expected: 2")
    assert result == 2, f"Expected 2, got {result}"
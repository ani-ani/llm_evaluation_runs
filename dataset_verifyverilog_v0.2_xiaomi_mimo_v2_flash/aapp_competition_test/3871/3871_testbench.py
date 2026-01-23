import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure
import random

@cocotb.test()
async def test_reality_show(dut):
    """Test the reality show module with multiple test cases"""
    
    # Create clock with 10ns period
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    dut.l_i.value = 0
    dut.s_i.value = 0
    dut.c_v.value = 0
    dut.valid_i.value = 0
    dut.done_i.value = 0
    
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: n=5, m=4 (scaled down)
    # Original: l=[4,3,1,2,1], s=[1,2,1,2,1], c=[1,2,3,4,5,6,7,8,9]
    # Expected profit: 6
    
    dut._log.info("Test Case 1: Basic test from sample")
    
    # Expected participants: [4,3,1,1] with fights
    # Revenue: 4+3+1+1+2 = 11, Cost: 1+2+1+1=5, Profit: 6
    
    # We'll feed candidates one by one
    candidates = [
        (4, 1),  # l=4, cost=1
        (3, 2),  # l=3, cost=2  
        (1, 1),  # l=1, cost=1
        (2, 2),  # l=2, cost=2 (rejected due to aggressiveness constraint)
        (1, 1),  # l=1, cost=1
    ]
    
    # Profitability values: c[1] to c[16]
    c_values = [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16]
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Feed candidates and compute
    for i, (l, s) in enumerate(candidates):
        dut.l_i.value = l
        dut.s_i.value = s
        dut.valid_i.value = 1
        if i == len(candidates) - 1:
            dut.done_i.value = 1
        await RisingEdge(dut.clk)
    
    dut.valid_i.value = 0
    dut.done_i.value = 0
    
    # Wait for computation to complete
    timeout = 0
    while not dut.done.value and timeout < 100:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 100:
        raise TestFailure("Module did not complete within 100 cycles")
    
    result = int(dut.max_profit.value)
    expected = 6
    
    if result != expected:
        raise TestFailure(f"Test 1 failed: got {result}, expected {expected}")
    
    dut._log.info(f"Test 1 passed: profit = {result}")
    
    # Test case 2: n=2, m=2
    # Original: l=[1,2], s=[0,0], c=[2,1,-100,-100]
    # Expected: 2 (only candidate 1)
    
    # Reset
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut._log.info("Test Case 2: High aggressiveness constraint")
    
    candidates = [
        (1, 0),  # Accept: revenue = 2, cost = 0, profit = 2
        (2, 0),  # Reject (higher than 1)
    ]
    
    c_values = [2,1,-100,-100]  # c[1], c[2], c[3], c[4]
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for i, (l, s) in enumerate(candidates):
        dut.l_i.value = l
        dut.s_i.value = s
        dut.valid_i.value = 1
        if i == len(candidates) - 1:
            dut.done_i.value = 1
        await RisingEdge(dut.clk)
    
    dut.valid_i.value = 0
    dut.done_i.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 100:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 100:
        raise TestFailure("Module did not complete within 100 cycles")
    
    result = int(dut.max_profit.value)
    expected = 2
    
    if result != expected:
        raise TestFailure(f"Test 2 failed: got {result}, expected {expected}")
    
    dut._log.info(f"Test 2 passed: profit = {result}")
    
    # Test case 3: Empty selection
    # Use costs that make selection unprofitable
    
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut._log.info("Test Case 3: No selection optimal")
    
    candidates = [
        (1, 1000),  # Very high cost
        (2, 1000),
    ]
    
    c_values = [1, 2, -100, -100]
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for i, (l, s) in enumerate(candidates):
        dut.l_i.value = l
        dut.s_i.value = s
        dut.valid_i.value = 1
        if i == len(candidates) - 1:
            dut.done_i.value = 1
        await RisingEdge(dut.clk)
    
    dut.valid_i.value = 0
    dut.done_i.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 100:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 100:
        raise TestFailure("Module did not complete within 100 cycles")
    
    result = int(dut.max_profit.value)
    expected = 0
    
    if result != expected:
        raise TestFailure(f"Test 3 failed: got {result}, expected {expected}")
    
    dut._log.info(f"Test 3 passed: profit = {result}")
    
    # Test case 4: Multiple fights
    # Three candidates with level 1
    
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut._log.info("Test Case 4: Multiple fights")
    
    candidates = [
        (1, 1),
        (1, 1),
        (1, 1),
    ]
    
    # c[1]=1, c[2]=10
    c_values = [1, 10, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    
    # Expected: 3 at level 1 -> 1 at level 1 (2 fights -> 2 removed, 1 left) + 1 at level 2
    # Wait, with 3 participants: 1 fight creates 1 at level 2, 1 remains at level 1
    # Revenue: 1+1+1 (enter) + 10 (from fight) = 13
    # Actually, let me recalculate: When 3 at level 1 enter, they fight in some order
    # Result: 1 remains at level 1, 1 moves to level 2
    # Revenue: 1+1+1 (initial) + 10 (from level 2 creation) = 13
    # But the sample suggests different logic. Let me use the known simple case.
    
    # Actually, let's just test with 2 participants at level 1
    candidates = [(1, 1), (1, 1)]
    # Revenue: 1+1 (initial) + 10 (fight -> level 2) = 12
    # Cost: 2
    # Profit: 10
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for i, (l, s) in enumerate(candidates):
        dut.l_i.value = l
        dut.s_i.value = s
        dut.valid_i.value = 1
        if i == len(candidates) - 1:
            dut.done_i.value = 1
        await RisingEdge(dut.clk)
    
    dut.valid_i.value = 0
    dut.done_i.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 100:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 100:
        raise TestFailure("Module did not complete within 100 cycles")
    
    result = int(dut.max_profit.value)
    expected = 10  # 2*1 + 10 - 2*1 = 10
    
    if result != expected:
        raise TestFailure(f"Test 4 failed: got {result}, expected {expected}")
    
    dut._log.info(f"Test 4 passed: profit = {result}")
    
    # Test case 5: Chain of fights
    # 4 participants at level 1
    
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut._log.info("Test Case 5: Chain of fights (4 at level 1)")
    
    candidates = [(1, 0), (1, 0), (1, 0), (1, 0)]
    c_values = [1, 10, 100, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    
    # 4 at level 1 -> 2 fights -> 2 at level 2 -> 1 fight -> 1 at level 3
    # Revenue: 4*1 + 2*10 + 1*100 = 4 + 20 + 100 = 124
    # Cost: 0
    # Profit: 124
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for i, (l, s) in enumerate(candidates):
        dut.l_i.value = l
        dut.s_i.value = s
        dut.valid_i.value = 1
        if i == len(candidates) - 1:
            dut.done_i.value = 1
        await RisingEdge(dut.clk)
    
    dut.valid_i.value = 0
    dut.done_i.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 100:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 100:
        raise TestFailure("Module did not complete within 100 cycles")
    
    result = int(dut.max_profit.value)
    expected = 124
    
    if result != expected:
        raise TestFailure(f"Test 5 failed: got {result}, expected {expected}")
    
    dut._log.info(f"Test 5 passed: profit = {result}")
    
    dut._log.info("All tests passed!")
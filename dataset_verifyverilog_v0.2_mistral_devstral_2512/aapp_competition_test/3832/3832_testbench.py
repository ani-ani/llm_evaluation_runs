import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_hill_houses(dut):
    """Test hill houses DP computation with scaled inputs"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.valid.value = 0
    dut.hill_height.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: [1,1,1,1,1] n=5
    dut._log.info("Test Case 1: All heights equal (1,1,1,1,1)")
    expected = [1, 2, 2]  # Costs for k=1,2,3
    n = 5
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Feed hills
    heights = [1, 1, 1, 1, 1]
    for h in heights:
        dut.hill_height.value = h
        dut.valid.value = 1
        await RisingEdge(dut.clk)
    
    # Feed remaining hills (pad to 10)
    for _ in range(5):
        dut.hill_height.value = 0
        dut.valid.value = 1
        await RisingEdge(dut.clk)
    
    dut.valid.value = 0
    
    # Wait for computation
    for _ in range(20):
        await RisingEdge(dut.clk)
        if dut.result_valid.value == 1:
            k = int(dut.current_k.value)
            cost_q16 = int(dut.min_cost.value)
            cost = cost_q16 >> 16  # Convert Q16.16 to integer
            if k <= 3:
                dut._log.info(f"k={k}, cost={cost} (expected {expected[k-1]})")
                if cost != expected[k-1]:
                    raise TestFailure(f"k={k}: got {cost}, expected {expected[k-1]}")
    
    if dut.done.value != 1:
        await RisingEdge(dut.clk)
    
    assert dut.done.value == 1, "Done signal not asserted"
    
    # Test case 2: [1,2,3] n=3
    dut._log.info("Test Case 2: [1,2,3]")
    
    # Reset for next test
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    expected = [0, 2]  # Costs for k=1,2
    heights = [1, 2, 3]
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for h in heights:
        dut.hill_height.value = h
        dut.valid.value = 1
        await RisingEdge(dut.clk)
    
    # Pad to 10
    for _ in range(7):
        dut.hill_height.value = 0
        dut.valid.value = 1
        await RisingEdge(dut.clk)
    
    dut.valid.value = 0
    
    results = {}
    for _ in range(20):
        await RisingEdge(dut.clk)
        if dut.result_valid.value == 1:
            k = int(dut.current_k.value)
            cost = int(dut.min_cost.value) >> 16
            results[k] = cost
            dut._log.info(f"k={k}, cost={cost}")
    
    for k in range(1, 3):
        if k not in results:
            raise TestFailure(f"Missing result for k={k}")
        if results[k] != expected[k-1]:
            raise TestFailure(f"k={k}: got {results[k]}, expected {expected[k-1]}")
    
    # Test case 3: [1,2,3,2,2] n=5
    dut._log.info("Test Case 3: [1,2,3,2,2]")
    
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    expected = [0, 1, 3]  # Costs for k=1,2,3
    heights = [1, 2, 3, 2, 2]
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for h in heights:
        dut.hill_height.value = h
        dut.valid.value = 1
        await RisingEdge(dut.clk)
    
    for _ in range(5):
        dut.hill_height.value = 0
        dut.valid.value = 1
        await RisingEdge(dut.clk)
    
    dut.valid.value = 0
    
    results = {}
    for _ in range(25):
        await RisingEdge(dut.clk)
        if dut.result_valid.value == 1:
            k = int(dut.current_k.value)
            cost = int(dut.min_cost.value) >> 16
            results[k] = cost
            dut._log.info(f"k={k}, cost={cost}")
    
    for k in range(1, 4):
        if k not in results:
            raise TestFailure(f"Missing result for k={k}")
        if results[k] != expected[k-1]:
            raise TestFailure(f"k={k}: got {results[k]}, expected {expected[k-1]}")
    
    # Test case 4: Edge case with n=1
    dut._log.info("Test Case 4: Single hill [10]")
    
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    expected = [0]  # Single hill needs no changes
    heights = [10]
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for h in heights:
        dut.hill_height.value = h
        dut.valid.value = 1
        await RisingEdge(dut.clk)
    
    # Pad to 10
    for _ in range(9):
        dut.hill_height.value = 0
        dut.valid.value = 1
        await RisingEdge(dut.clk)
    
    dut.valid.value = 0
    
    results = {}
    for _ in range(20):
        await RisingEdge(dut.clk)
        if dut.result_valid.value == 1:
            k = int(dut.current_k.value)
            cost = int(dut.min_cost.value) >> 16
            results[k] = cost
            dut._log.info(f"k={k}, cost={cost}")
    
    if 1 in results and results[1] != 0:
        raise TestFailure(f"Single hill: got {results[1]}, expected 0")
    
    dut._log.info("All tests passed!")

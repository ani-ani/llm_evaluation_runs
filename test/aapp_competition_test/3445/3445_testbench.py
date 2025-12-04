import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

@cocotb.test()
async def test_courier_partition(dut):
    # Generate 100MHz clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset initialization
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: Clustered points (scaled version of first example)
    points = [
        (1, 1), (4, 1), (1, 5), (10, 10), (10, 8), (7, 10)  # Original points scaled for 4-bit 
    ]
    # Scale coordinates to fit 4-bit range (0-15)
    scaled_points = [(x//64, y//64) for (x,y) in points]  # Original 0-1000 -> 0-15 scale
    print(f"Test points: {scaled_points}")
    
    # Load inputs (only 6 customers)
    dut.num_customers.value = 6
    for i in range(8):
        if i < len(scaled_points):
            dut.x[i].value = scaled_points[i][0]
            dut.y[i].value = scaled_points[i][1]
        else:
            dut.x[i].value = 0
            dut.y[i].value = 0
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done signal (timeout after 400 cycles)
    cycles = 0
    while not dut.done.value and cycles < 400:
        await RisingEdge(dut.clk)
        cycles += 1
    
    # Verify output
    assert dut.done.value == 1, "Test 1: Computation timed out"
    # Expected result - original solution was 7, scaled points have max distance of 7 (after scaling so check may differ)
    expected = 7  # Adjusted for scaled coordinates - depends on actual implementation
    assert dut.min_max_time.value == expected, f"Test 1: Got {dut.min_max_time.value}, expected {expected}"
    
    # Test case 2: Extreme spread (scaled second input)
    points = [
        (0,0), (15,15), (0,15), (15,0), (7,7), (0,7), (15,7)
    ]
    dut.num_customers.value = 7
    for i, (x,y) in enumerate(points):
        dut.x[i].value = x
        dut.y[i].value = y
    
    # Restart
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    cycles = 0
    while not dut.done.value and cycles < 400:
        await RisingEdge(dut.clk)
        cycles += 1
    
    assert dut.done.value == 1, "Test 2: Computation timed out"
    expected = 30  # Maximum possible distance (15+15)
    assert dut.min_max_time.value == expected, f"Test 2: Got {dut.min_max_time.value}, expected {expected}"
    
    # Test case 3: Minimal case (3 customers)
    points = [(1,1), (1,2), (3,1)]
    dut.num_customers.value = 3
    for i in range(8):
        if i < len(points):
            dut.x[i].value, dut.y[i].value = points[i]
        else:
            dut.x[i].value, dut.y[i].value = 0,0
    
    dut.rst_n.value = 0; await RisingEdge(dut.clk); dut.rst_n.value = 1; await RisingEdge(dut.clk);
    dut.start.value = 1; await RisingEdge(dut.clk); dut.start.value = 0;
    
    cycles = 0
    while not dut.done.value and cycles < 400:
        await RisingEdge(dut.clk)
        cycles += 1
    
    assert dut.done.value == 1, "Test 3: Timeout"
    # For 3 points, max distance would be either 2 (0-1-2) or 3 (0-2)
    assert dut.min_max_time.value == 2, f"Test 3: Got {dut.min_max_time.value}, expected 2"
    
    dut._log.info("3/3 tests passed")
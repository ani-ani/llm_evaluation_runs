import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer, ClockCycles
import math

@cocotb.test()
async def test_connected_towers(dut):
    # Convert float to Q10.6 fixed-point: value * 64
    def to_q10_6(f):
        return int(f * 64) & 0xFFFF
    
    # Build test case data (scaled down from original examples)
    test_cases = [
        (5, [(1.0, 1.0), (3.1, 1.0), (1.0, 3.1), (3.1, 3.1), (4.2, 3.1)], 6),
        (5, [(1.0, 1.0), (3.1, 1.0), (1.0, 3.1), (3.1, 3.1), (10.0, 10.0)], 5)
    ]
    
    clock = Clock(dut.clk, 10, units="ns")  # Create 10ns period clock
    cocotb.start_soon(clock.start())  # Start the clock
    
    # Initialize/reset
    dut.rst_n.value = 0
    dut.start.value = 0
    for i in range(8):
        dut.tower_x[i].value = 0
        dut.tower_y[i].value = 0
    dut.num_towers.value = 0
    await Timer(20, units="ns")
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    passed = 0
    for (n, towers, expected) in test_cases:
        # Load tower data
        dut.num_towers.value = n
        for i in range(8):
            if i < n:
                x, y = towers[i]
                dut.tower_x[i].value = to_q10_6(x)
                dut.tower_y[i].value = to_q10_6(y)
            else:
                dut.tower_x[i].value = 0
                dut.tower_y[i].value = 0
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (worst-case latency for n=8: 6+16=22 cycles)
        for _ in range(25):
            if dut.done.value == 1:
                break
            await RisingEdge(dut.clk)
        
        # Verify result
        result = dut.max_count.value.integer
        if result == expected:
            passed += 1
        else:
            dut._log.error(f"Test failed: n={n} towers={towers}
  Result: {result}, Expected: {expected}")
        
        await ClockCycles(dut.clk, 2)  # Wait 2 cycles between tests
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_mps(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Adapted test cases
    test_cases = [
        (4, [30, 20, 100, 0], [0, 30, -50, 0], [35, 35, 200, 20], "01", 45, 5),  # Unique solution
        (2, [0, 100], [0, 0], [50, 50], "10", 0, 0),  # Uncertain
        (2, [0, 100], [0, 0], [50, 1], "11", 0, 0),   # Impossible
        (1, [100], [50], [30], "10", 0, 0)           # Multiple valid (single beacon)
    ]
    
    await Timer(20, units="ns")
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    
    passed = 0
    for i, (n, xs, ys, ds, exp_stat, exp_x, exp_y) in enumerate(test_cases):
        # Load inputs
        dut.start.value = 0
        dut.beacon_count.value = n-1  # 0-based count (1 beacon = 0)
        for b in range(4):
            dut.x[b].value = xs[b] if b < n else 0
            dut.y[b].value = ys[b] if b < n else 0
            dut.d[b].value = ds[b] if b < n else 0
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (max 1024 cycles)
        for _ in range(1100):
            await RisingEdge(dut.clk)
            if dut.status.value != 0:
                break
        
        # Check outputs
        if dut.status.value.binstr == exp_stat:
            if exp_stat == "01":  # Verify coordinates
                if dut.x_r.value.integer == exp_x and dut.y_r.value.integer == exp_y:
                    passed += 1
                else:
                    dut._log.error(f"Test {i}: Wrong position {dut.x_r.value},{dut.y_r.value} != {exp_x},{exp_y}")
            else:
                passed += 1
        else:
            dut._log.error(f"Test {i}: Wrong status {dut.status.value} != {exp_stat}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
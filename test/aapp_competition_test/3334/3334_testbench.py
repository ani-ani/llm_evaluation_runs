import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock
from cocotb.result import TestFailure
import numpy as np

@cocotb.test()
async def test_sign_avg(dut):
    clock = Clock(dut.clk, 10, units="ns")  
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await ClockCycles(dut.clk, 2)
    dut.rst_n.value = 1
    
    test_cases = [
        {"n": 3, "dists": [4,4,2], "expected": int(2.13333333333333 * 65536)}
        {"n": 4, "dists": [2,2,2,2,2,2], "expected": int(1.6 * 65536)}
    ]
    
    passed = 0
    for case in test_cases:
        # Load inputs
        dut.n.value = case["n"]
        for i in range(6):
            dut.dist_matrix[i].value = case["dists"][i] if i < len(case["dists"]) else 0
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (max 20 cycles)
        await ClockCycles(dut.clk, 20)
        if not dut.done.value:
            raise TestFailure("Timeout waiting for done")
        
        # Check outputs
        actual_fp = dut.avg_distance.value.integer if dut.avg_distance.value.is_resolvable else 0
        expected_fp = case["expected"]
        
        # Allow 0.001% tolerance for fixed-point error
        if abs(actual_fp - expected_fp)/expected_fp < 1e-5:
            passed += 1
        else:
            actual = actual_fp / 65536.0
            expected = case["expected"] / 65536.0
            msg = f"Failed: Got {actual}, expected {expected} (FP: {actual_fp} vs {expected_fp})"
            dut._log.error(msg)
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
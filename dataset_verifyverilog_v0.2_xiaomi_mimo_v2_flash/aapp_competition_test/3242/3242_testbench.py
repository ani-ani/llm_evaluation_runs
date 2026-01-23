import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
import random

def to_fixed_point(value):
    """Convert float to Q8.8 integer representation"""
    return int(value * 256)

def simulate_dp(boxes, target_prob):
    """Reference Python implementation of the DP algorithm"""
    target_idx = int(target_prob * 256)
    max_idx = 2048 # 8*256
    dp = [float('inf')] * (max_idx + 1)
    dp[0] = 0
    
    for e, p in boxes:
        p_idx = int(p * 256)
        # Iterate backwards
        for i in range(max_idx, -1, -1):
            if dp[i] != float('inf'):
                new_idx = i + p_idx
                if new_idx <= max_idx:
                    dp[new_idx] = min(dp[new_idx], dp[i] + e)
    
    # Find min energy for target or greater
    min_energy = float('inf')
    for i in range(target_idx, max_idx + 1):
        min_energy = min(min_energy, dp[i])
    
    return min_energy

@cocotb.test()
async def test_find_min_energy(dut):
    """Test find_min_energy module with various cases"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.load_valid.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases (N, P, [(e, p), ...])
    test_cases = [
        (2, 0.5, [(2, 0.5), (1, 0.5)]),
        (2, 0.5, [(2, 0.51), (1, 0.49)]),
        (2, 1.0, [(2, 0.3291), (5, 0.6709)])
    ]
    
    dut._log.info("Starting tests...")
    passed = 0
    total = len(test_cases)
    
    for n_boxes, target_p, boxes in test_cases:
        dut._log.info(f"Running test: N={n_boxes}, P={target_p}")
        
        # 1. Load data
        dut.load_valid.value = 1
        dut.num_boxes.value = n_boxes
        dut.target_prob.value = to_fixed_point(target_p)
        
        for e, p in boxes:
            # Wait for ready (optional, assuming always ready in IDLE/LOAD)
            # Here we just drive data
            dut.energy_in.value = e
            dut.prob_in.value = to_fixed_point(p)
            await RisingEdge(dut.clk)
        
        dut.load_valid.value = 0
        
        # 2. Start computation
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # 3. Wait for valid
        timeout = 0
        while not dut.valid.value and timeout < 2000:
            await RisingEdge(dut.clk)
            timeout += 1
            
        assert dut.valid.value, "Timeout waiting for valid signal"
        
        # 4. Check result
        ref = simulate_dp(boxes, target_p)
        dut_result = int(dut.min_energy.value)
        
        dut._log.info(f"Expected: {ref}, Got: {dut_result}")
        
        # Allow small floating point diffs
        assert abs(dut_result - ref) <= 1, f"Mismatch: Expected {ref}, Got {dut_result}"
        passed += 1
        
        # Brief pause between tests
        await Timer(100, units='ns')
        await RisingEdge(dut.clk)

    dut._log.info(f"Summary: {passed}/{total} tests passed")
    assert passed == total

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
import random

@cocotb.test()
async def test_traffic_probability(dut):
    """Test traffic probability calculation with 4 simplified lights"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.config_valid.value = 0
    await Timer(100, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Light Configuration Data (x, r, g)
    # Light 0: x=1, r=2, g=3 (Cycle=5)
    # Light 1: x=6, r=2, g=3 (Cycle=5)
    # Light 2: x=10, r=2, g=3 (Cycle=5)
    # Light 3: x=16, r=3, g=4 (Cycle=7)
    lights = [
        (1, 2, 3),
        (6, 2, 3),
        (10, 2, 3),
        (16, 3, 4)
    ]
    
    # Configure lights
    for i, (x, r, g) in enumerate(lights):
        dut.light_index.value = i
        dut.x_pos.value = x
        dut.r_dur.value = r
        dut.g_dur.value = g
        dut.config_valid.value = 1
        await RisingEdge(dut.clk)
        dut.config_valid.value = 0
        await RisingEdge(dut.clk)
        
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 0
    while dut.done.value == 0:
        await RisingEdge(dut.clk)
        timeout += 1
        if timeout > 5000:
            dut._log.error("Timeout waiting for done signal")
            assert False
            
    # Read results
    # Expected results (approximate based on LCM=35, step=0.25 -> 140 samples)
    # Light 0 prob: 0.4 (4/10)
    # Light 1 prob: 0.0
    # Light 2 prob: 0.2 (2/10)
    # Light 3 prob: 0.1714...
    # Pass prob: 0.2285...
    
    # We must read from the array outputs. Verilog reg arrays map to signals.
    # We assume Verilog outputs are accessible as dut.prob_stop_0, dut.prob_stop_1...
    # Or dut.prob_stop[i]. Let's assume dut.prob_stop_i naming for simplicity in Python.
    
    probs_stop = []
    for i in range(4):
        val = getattr(dut, f"prob_stop_{i}").value
        probs_stop.append(val)
        
    prob_pass_val = dut.prob_pass.value
    
    # Convert Q16.16 to float
    def q16_to_float(val):
        if val >= 2**31:
            val = val - 2**32
        return val / 65536.0
        
    p_stop = [q16_to_float(v) for v in probs_stop]
    p_pass = q16_to_float(prob_pass_val)
    
    dut._log.info(f"Probabilities: Stop={p_stop}, Pass={p_pass}")
    
    # Verify
    # Tolerance 0.01 is reasonable for discrete simulation
    assert abs(p_stop[0] - 0.4) < 0.01, f"Light 0 prob fail: {p_stop[0]}"
    assert abs(p_stop[1] - 0.0) < 0.01, f"Light 1 prob fail: {p_stop[1]}"
    assert abs(p_stop[2] - 0.2) < 0.01, f"Light 2 prob fail: {p_stop[2]}"
    assert abs(p_stop[3] - 0.1714) < 0.01, f"Light 3 prob fail: {p_stop[3]}"
    assert abs(p_pass - 0.2285) < 0.01, f"Pass prob fail: {p_pass}"
    
    dut._log.info("All tests passed!")

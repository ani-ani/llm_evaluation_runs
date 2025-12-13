import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import numpy as np

# Fixed-point conversion helpers
def to_q16_16(val):
    return int(val * 65536)

def from_q16_16(val):
    return val / 65536.0

@cocotb.test()
async def test_cone_lsa(dut):
    # Fixed π approximation (3.141586)
    PI_Q16 = 0x3243F
    
    # Generate clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Test cases (r, h, expected_lsa)
    test_cases = [
        # Original: (5,12)=204.2035
        (to_q16_16(5), to_q16_16(12), to_q16_16(204.2035)),
        # Original: (10,15)=566.3586
        (to_q16_16(10), to_q16_16(15), to_q16_16(566.3586)),
        # Original: (19,17)=1521.809
        (to_q16_16(19), to_q16_16(17), to_q16_16(1521.809)),
        # Edge cases
        (0, 0, 0),
        (to_q16_16(1), to_q16_16(0), 0)
    ]
    
    passed = 0
    
    for r_val, h_val, expected in test_cases:
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Apply inputs
        dut.r_q16.value = r_val
        dut.h_q16.value = h_val
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        for _ in range(15):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        
        # Check result (allow 1% tolerance for fixed-point approx)
        actual = dut.lsa_q16.value.integer
        expected_min = expected * 0.99
        expected_max = expected * 1.01
        
        if expected == 0:
            check = (actual == 0)
        else:
            check = (expected_min <= actual <= expected_max)
        
        if check:
            passed += 1
            dut._log.info(f"PASS: r={from_q16_16(r_val)} h={from_q16_16(h_val)} got={from_q16_16(actual):.2f} expected≈{from_q16_16(expected):.2f}")
        else:
            dut._log.error(f"FAIL: r={from_q16_16(r_val)} h={from_q16_16(h_val)} got={from_q16_16(actual):.2f} expected≈{from_q16_16(expected):.2f}")
        
        # Reset between tests
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
    
    dut._log.info(f"
{passed}/{len(test_cases)} tests passed")
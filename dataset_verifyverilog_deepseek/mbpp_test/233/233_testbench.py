import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import math

@cocotb.test()
async def test_cylinder(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Q16.16 conversion helper
    def float_to_q16(value):
        return int(value * (1 << 16)) & 0xFFFFFFFF
    
    test_cases = [
        # Original: (10, 5, 314.15)
        {'r': 10.0, 'h': 5.0, 'expected': 2*math.pi*10*5},
        # Original: (4, 5, 125.66)
        {'r': 4.0, 'h': 5.0, 'expected': 2*math.pi*4*5},
        # Original: (4, 10, 251.32)
        {'r': 4.0, 'h': 10.0, 'expected': 2*math.pi*4*10},
        # Additional edge case
        {'r': 0.0, 'h': 10.0, 'expected': 0.0},
    ]
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    passed = 0
    tol = 0.01  # 1% tolerance
    
    for test in test_cases:
        # Convert inputs
        dut.radius.value = float_to_q16(test['r'])
        dut.height.value = float_to_q16(test['h'])
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait 2 cycles for result
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        
        # Convert output from Q16.16 float
        result_q = dut.result.value.integer
        result_float = result_q / (1 << 32)  # Q16.16×Q16.16=Q32.32
        
        # Check tolerance
        diff = abs(result_float - test['expected'])
        if test['expected'] != 0:
            rel_error = diff / test['expected']
        else:
            rel_error = diff
        
        if rel_error <= tol:
            passed += 1
            dut._log.info(f"PASS: r={test['r']}, h={test['h']} got {result_float:.2f} expected {test['expected']:.2f}")
        else:
            dut._log.error(f"FAIL: r={test['r']}, h={test['h']} got {result_float:.2f} expected {test['expected']:.2f}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import struct

# Q16.16 helper functions
def float_to_q16_16(f):
    return int(f * (1 << 16)) & 0xFFFFFFFF

def q16_16_to_float(q):
    return q / (1 << 16) if q < 0x80000000 else (q - 0x100000000)/(1 << 16)

@cocotb.test()
async def test_speedrun(dut):
    clock = Clock(dut.clk, 10, units='ns')  # 100 MHz clock
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    
    test_cases = [
        # Test Case 1 (adapted to 4 tricks)
        {'n': 100, 'r': 111, 'm': 4, 'tricks': [
            (20, 0.5, 10), 
            (80, 0.5, 2), 
            (85, 0.5, 2), 
            (90, 0.5, 2)
        ], 'expected': 124.0},
        
        # Test Case 2
        {'n': 2, 'r': 4, 'm': 1, 'tricks': [
            (1, 0.5, 5), 
            (0, 0, 0), 
            (0, 0, 0), 
            (0, 0, 0)
        ], 'expected': 3.0},
        
        # Test Case 3
        {'n': 10, 'r': 20, 'm': 3, 'tricks': [
            (5, 0.3, 8), 
            (6, 0.8, 3), 
            (8, 0.9, 3), 
            (0, 0, 0)
        ], 'expected': 18.902985}
    ]
    
    passed = 0
    for case in test_cases:
        # Load inputs
        dut.n.value = case['n']
        dut.r.value = case['r']
        dut.m.value = case['m']
        
        for i in range(4):
            t, p, d = case['tricks'][i]
            dut.trick_t[i].value = t
            dut.trick_p[i].value = float_to_q16_16(p)
            dut.trick_d[i].value = d
        
        # Start calculation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (max 50 cycles)
        for _ in range(60):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        else:
            assert False, "Timeout waiting for done signal"
        
        # Verify result (0.1% tolerance)
        result = q16_16_to_float(dut.result.value)
        expected = case['expected']
        if abs(result - expected) < expected*0.001:
            passed += 1
        else:
            dut._log.error(f"Failed: Expected {expected}, got {result}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
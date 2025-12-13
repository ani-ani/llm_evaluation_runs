import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
import numpy as np

# Q16.16 fixed-point conversion functions
def float_to_q16_16(f):
    return int(f * (1 << 16)) & 0xFFFFFFFF

def q16_16_to_float(q):
    return (q if q < 0x80000000 else q - 0x100000000) / 65536.0

@cocotb.test()
async def test_lemonade_trader(dut):
    # Create 50MHz clock
    clock = Clock(dut.clk, 20, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    
    # Color ID mapping
    COLOR_MAP = {"pink": 0, "blue":1, "red":2, "orange":3,\\
                 "yellow":4, "green":5, "indigo":6, "violet":7,\\
                 "purple":8}
    
    # Test cases (adapted to fit 8 children max)
    test_cases = [
        {
            "input": [
                ("blue", "pink", 1.0),
                ("red", "pink", 1.5),
                ("blue", "red", 1.0)
            ],
            "expected": 1.5
        },
        {
            "input": [
                ("blue", "red", 1.0),
                ("red", "pink", 1.5)
            ],
            "expected": 0.0
        },
        {
            "input": [
                ("orange", "pink", 1.9),
                ("yellow", "orange", 1.9),
                ("green", "yellow", 1.9),
                ("blue", "green", 1.9)
            ],
            "expected": 10.0
        },
        {
            "input": [
                ("red", "pink", 1.9),
                ("orange", "red", 1.9),
                ("yellow", "orange", 1.9),
                ("green", "yellow", 1.9),
                ("indigo", "green", 0.6),
                ("violet", "indigo", 0.6),
                ("purple", "violet", 0.6),
                ("blue", "purple", 0.6)
            ],
            "expected": 1.68896016
        }
    ]
    
    passed = 0
    total = len(test_cases)
    EPSILON = 1e-6  # Precision requirement
    
    for case in test_cases:
        # Setup inputs
        dut.num_children.value = len(case["input"])
        
        # Initialize color_ids and rates arrays
        for i in range(8):
            if i < len(case["input"]):
                offer, want, rate = case["input"][i]
                dut.color_ids[i].value = COLOR_MAP[offer]  # Store OFFER color
                # Not explicit in design but assumed that WANT is chain target - limitation
                dut.rates[i].value = float_to_q16_16(rate)
            else:
                dut.color_ids[i].value = 0
                dut.rates[i].value = 0
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done signal (max 256 cycles)
        timeout = 0
        while not dut.done.value and timeout < 300:
            await RisingEdge(dut.clk)
            timeout += 1
        
        if timeout >= 300:
            dut._log.error("Timeout waiting for done signal")
        else:
            # Verify result
            result = q16_16_to_float(dut.max_blue_q16.value)
            expected = case["expected"]
            
            if abs(result - expected) < EPSILON or 
               (expected >= 10.0 and result >= 10.0):
                passed += 1
            else:
                dut._log.error("Test failed: Expected %.9f, got %.9f (Q16.16: 0x%08X)\\
                                expected, result, dut.max_blue_q16.value)
    
    dut._log.info(f"{passed}/{total} tests passed")

import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import numpy as np

@cocotb.test()
async def test_love_potion(dut):
    """Test adapted Python cases with n=8 chemicals"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    test_cases = [
        # Adapted first sample (4 chemicals → pad with zeros)
        {'a': [2,2,2,2,0,0,0,0], 'k': 2, 'expected':8},
        # Adapted second sample
        {'a': [3,-6,-3,12,-5,0,0,0], 'k': -3, 'expected':3},
        # Edge case: single element
        {'a': [2,0,0,0,0,0,0,0], 'k': 2, 'expected':1},
        # All zeros case (power k=0=1)
        {'a': [0,0,0,0,0,0,0,0], 'k': 5, 'expected':36}
    ]
    passed = 0
    for case in test_cases:
        # Reset sequence
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        # Load inputs
        for i in range(8):
            dut.a[i].value = int(np.int8(case['a'][i]))
        dut.k.value = int(np.int8(case['k']))
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        # Wait until done
        for _ in range(200):
            await RisingEdge(dut.clk)
            if dut.done.value:
                break
        # Check result
        if dut.count.value == case['expected']:
            passed += 1
        else:
            dut._log.error(f"FAIL: Expected {case['expected']}, got {dut.count.value}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")

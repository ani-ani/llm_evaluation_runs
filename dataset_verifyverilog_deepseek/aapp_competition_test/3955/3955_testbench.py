import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_max_or(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    \
    test_cases = [
        # Original input scaled: 3 elements, k=1, x=2, arr=[1,1,1]
        {'k':1, 'x':2, 'arr':[1,1,1,0,0,0,0,0], 'expected':3},
        # Original input scaled: 4 elements, k=2, x=3 - output becomes 1*9|2|4|72 = 79
        {'k':2, 'x':3, 'arr':[1,2,4,8,0,0,0,0], 'expected':79},
        # Edge case: single element with maximum multiplication
        {'k':7, 'x':4, 'arr':[255,0,0,0,0,0,0,0], 'expected': 255*(4**7)},
        # All zeros case
        {'k':3, 'x':2, 'arr':[0,0,0,0,0,0,0,0], 'expected':0},
        # Mixed values case (scaled 8-bit inputs)
        {'k':1, 'x':2, 'arr':[10,12,5,0,0,0,0,0], 'expected':31}
    ]
    passed = 0
    \
    for case in test_cases:
        dut.start.value = 0
        # Apply test vectors
        dut.k.value = case['k']
        dut.x.value = case['x']
        for i in range(8):
            dut.arr[i].value = case['arr'][i]
        \
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        \
        # Wait for completion (1 cycle latency)
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        \
        # Verify output
        if dut.done.value == 1 and dut.result.value == case['expected']:
            passed += 1
        else:
            dut._log.error("Test failed: k={} x={} arr={} result={}, expected={}".format(
                case['k'], case['x'], case['arr'], dut.result.value, case['expected']))
    \
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)
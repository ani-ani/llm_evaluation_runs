import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock
from cocotb.utils import get_sim_time
import numpy as np

@cocotb.test()
async def test_max_subarray(dut):
    # Clock setup
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    test_cases = [
        # Original Test 1: [-2, -3, 4, -1, -2, 1, 5, -3] -> sum=7
        {'a': (-2,-3,4,-1,-2,1,5,-3), 'exp': 7},
        # Original Test 2: [-3,-4,5,-2,-3,2,6,-4] -> sum=8
        {'a': (-3,-4,5,-2,-3,2,6,-4), 'exp': 8},
        # Original Test 3: [-4,-5,6,-3,-4,3,7,-5] -> sum=10
        {'a': (-4,-5,6,-3,-4,3,7,-5), 'exp': 10},
        # Edge case: all negative
        {'a': (-1,-2,-3,-4,-5,-6,-7,-8), 'exp': 0},
        # All positive
        {'a': (1,2,3,4,5,6,7,8), 'exp': 36}
    ]

    passed = 0
    total = len(test_cases)

    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await ClockCycles(dut.clk, 2)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    for test in test_cases:
        # Load test inputs
        for i in range(8):
            dut.a[i].value = test['a'][i]
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (9 cycles latency)
        await ClockCycles(dut.clk, 9)
        
        # Check result
        if dut.done.value != 1:
            dut._log.error(f"FAIL: Done not asserted")
        else:
            got = dut.max_sum.value.signed_integer
            expected = test['exp']
            hex_val = format(dut.max_sum.value.integer, '#07x')
            
            if got == expected:
                passed += 1
                dut._log.info(f"PASS: {test['a']} -> {expected} (0x{hex_val[2:]})")
            else:
                dut._log.error(f"FAIL: Input {test['a']} -> Got {got} (0x{hex_val}), Expected {expected}")
        
        # Insert gap between tests
        await ClockCycles(dut.clk, 2)

    dut._log.info(f"SUMMARY: {passed}/{total} tests passed")
    assert passed == total, "Some tests failed"
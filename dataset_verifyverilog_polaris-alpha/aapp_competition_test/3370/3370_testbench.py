import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock
import numpy as np

# Q16.16 fixed-point helper functions
def float_to_q16_16(val):
    return int(round(val * (1 << 16)))

def q16_16_to_float(val):
    return val.signed_integer / (1 << 16)

@cocotb.test()
async def test_house_envy(dut):
    # Generate clock (100MHz)
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test case 1 (original sample): N=3, k=1
    test_cases = [
        {
            'n': 2,  # 3 houses (0-2)
            'k': float_to_q16_16(1.0),
            'h': [float_to_q16_16(39), float_to_q16_16(10), float_to_q16_16(40),
                  0, 0, 0, 0, 0],
            'expected': float_to_q16_16(40.5)  # Expected max height
        },
        # Test case 2 (simplified from second sample)
        {
            'n': 4,  # 5 houses
            'k': float_to_q16_16(0.1),
            'h': [float_to_q16_16(20.0), float_to_q16_16(10.0),
                  float_to_q16_16(5.0), float_to_q16_16(2.0),
                  float_to_q16_16(1.0), 0, 0, 0],
            'expected': float_to_q16_16(20.0)  # After stabilization
        }
    ]

    passed = 0
    total = len(test_cases)

    for case in test_cases:
        # Apply inputs
        dut.n.value = case['n']
        dut.k.value = case['k']
        dut.h0.value = case['h'][0]
        dut.h1.value = case['h'][1]
        dut.h2.value = case['h'][2]
        dut.h3.value = case['h'][3]
        dut.h4.value = case['h'][4]
        dut.h5.value = case['h'][5]
        dut.h6.value = case['h'][6]
        dut.h7.value = case['h'][7]

        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        await RisingEdge(dut.clk)

        # Wait for completion (100*(n+1)+2 cycles)
        max_cycles = 100 * (case['n'] + 2) + 10
        await ClockCycles(dut.clk, max_cycles)

        # Check result
        actual_val = q16_16_to_float(dut.max_height.value)
        expected_val = q16_16_to_float(case['expected'])
        error = abs(actual_val - expected_val)

        if error < 1e-6 or dut.max_height.value == case['expected']:
            passed += 1
        else:
            dut._log.error("Test failed: Expected %.6f (0x%08X), Got %.6f (0x%08X)" % 
                          (expected_val, case['expected'],
                           actual_val, dut.max_height.value.integer))

    dut._log.info(f"{passed}/{total} tests passed")

    if passed != total:
        raise cocotb.result.TestFailure()
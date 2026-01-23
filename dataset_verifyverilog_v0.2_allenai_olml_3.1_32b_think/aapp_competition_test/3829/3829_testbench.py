import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import math

def to_q16_16(value):
    return int(value * 65536)

def from_q16_16(value):
    # Handle signed values if necessary, but here values are positive
    return value / 65536.0

@cocotb.test()
async def test_expected_max_dice(dut):
    # Create a clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.m.value = 0
    dut.n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test cases: (m, n, expected_value)
    # Constraints: m, n <= 16 for the hardware implementation
    test_cases = [
        (1, 1, 1.0),
        (2, 1, 1.5),
        (6, 1, 3.5),
        (2, 2, 1.75),
        (6, 3, 4.958333333333),
        (3, 2, 2.333333333333),
        (4, 2, 2.75)
    ]

    passed = 0
    total = len(test_cases)

    for m, n, expected in test_cases:
        # Input values to DUT
        dut.m.value = m
        dut.n.value = n
        
        # Start signal
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done signal
        timeout = 0
        while dut.done.value == 0:
            await RisingEdge(dut.clk)
            timeout += 1
            if timeout > 2000: # Safety break
                print(f"Timeout for m={m}, n={n}")
                break
        
        # Read result
        result_raw = int(dut.result.value)
        result_float = from_q16_16(result_raw)
        
        # Compare with expected
        # Allow small relative error for fixed point arithmetic
        error = abs(result_float - expected)
        tolerance = 0.0005
        
        if error < tolerance:
            passed += 1
            print(f"Test passed: m={m}, n={n}. Result: {result_float:.6f}, Expected: {expected:.6f}")
        else:
            print(f"Test FAILED: m={m}, n={n}. Result: {result_float:.6f}, Expected: {expected:.6f}, Error: {error:.6f}")
        
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)

    print(f"Summary: {passed}/{total} tests passed")

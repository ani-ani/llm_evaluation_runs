import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure
import math

# Helper to convert float to Q16.16
def to_q16_16(val):
    return int(val * 65536) & 0xFFFF

# Helper to calculate expected wind chill
def python_wind_chill(v, t):
    # t is float, v is int
    if v < 0: v = 0
    term1 = 0.6215 * t
    v_pow = math.pow(v, 0.16)
    term2 = 11.37 * v_pow
    term3 = 0.3965 * t * v_pow
    result = 13.12 + term1 - term2 + term3
    return int(round(result))

@cocotb.test()
async def test_wind_chill(dut):
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.v.value = 0
    dut.t.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test cases: (v, t_celsius)
    test_cases = [
        (120, 35),
        (40, 20),
        (10, 8)
    ]

    passed = 0
    total = len(test_cases)

    for v, t_c in test_cases:
        # Convert input temperature to Q16.16
        t_fixed = to_q16_16(t_c)
        
        dut.v.value = v
        dut.t.value = t_fixed
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 20
        for _ in range(timeout):
            if dut.done.value == 1:
                break
            await RisingEdge(dut.clk)
        else:
            raise TestFailure(f"Timeout waiting for done for v={v}, t={t_c}")
        
        # Check result
        expected = python_wind_chill(v, t_c)
        actual = int(dut.result.value)
        
        if actual == expected:
            dut._log.info(f"PASS: v={v}, t={t_c} -> Result={actual} (Expected={expected})")
            passed += 1
        else:
            dut._log.error(f"FAIL: v={v}, t={t_c} -> Result={actual} (Expected={expected})")
            
        await RisingEdge(dut.clk) # Buffer between tests

    dut._log.info(f"
Summary: {passed}/{total} tests passed")
    assert passed == total, f"Test failed: {passed}/{total} passed"
}
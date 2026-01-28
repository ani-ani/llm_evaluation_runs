import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helper functions
def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def clamp_to_width(v, bits):
    mask = (1 << bits) - 1
    return int(v) & mask

def float_to_fixed(f, frac=16):
    return int(f * (1 << frac))

def fixed_to_float(v, frac=16):
    return v / (1 << frac)

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut):
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=300):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_expected_area(dut):
    # Setup Clock
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await reset_dut(dut)

    # Test Case 1: Sample Input 1
    # 4 vertices, k=3. Vertices: (0,0), (1,1), (2,1), (1,0)
    # Area of full polygon: 1.5. Expected area = 1.5 * (3/4) = 1.125
    n1 = 4
    k1 = 3
    coords1 = [(0, 0), (1, 1), (2, 1), (1, 0)]
    expected_area1 = 1.125

    # Test Case 2: Sample Input 2
    # 5 vertices, k=5 (full polygon)
    # Area calculated manually from coords is 25.0. Expected = 25.0 * (5/5) = 25.0
    n2 = 5
    k2 = 5
    coords2 = [(0, 4), (4, 2), (4, 1), (3, -1), (-2, 4)]
    expected_area2 = 25.0

    test_cases = [
        (n1, k1, coords1, expected_area1),
        (n2, k2, coords2, expected_area2)
    ]

    passed = 0
    failed = 0

    for idx, (n, k, coords, exp_area) in enumerate(test_cases):
        cocotb.log.info(f"Running Test Case {idx + 1}: n={n}, k={k}")
        
        # 1. Set Inputs
        dut.n.value = n
        dut.k.value = k
        
        # Fill coordinates (only up to n)
        for i in range(n):
            x_f = float_to_fixed(coords[i][0])
            y_f = float_to_fixed(coords[i][1])
            dut.x[i].value = x_f
            dut.y[i].value = y_f
        
        # Dummy values for remaining indices (though module should only read valid ones)
        for i in range(n, 16):
            dut.x[i].value = 0
            dut.y[i].value = 0

        # 2. Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # 3. Wait for Done
        try:
            await wait_for_done(dut)
        except TestFailure as e:
            cocotb.log.error(f"Test {idx+1} FAILED: {e}")
            failed += 1
            continue

        # 4. Check Result
        # Result is 64-bit Q32.32. Lower 32 bits are fractional.
        if not is_value_defined(dut.result.value):
            cocotb.log.error(f"Test {idx+1} FAILED: Result undefined")
            failed += 1
            continue

        result_int = int(dut.result.value)
        result_float = fixed_to_float(result_int, frac=32)
        
        # Allow absolute error 1e-5 (relaxed for fixed-point)
        if abs(result_float - exp_area) > 1e-5:
            cocotb.log.error(f"Test {idx+1} FAILED: Expected {exp_area:.6f}, Got {result_float:.6f}")
            failed += 1
        else:
            cocotb.log.info(f"Test {idx+1} PASSED: Got {result_float:.6f}")
            passed += 1

    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")

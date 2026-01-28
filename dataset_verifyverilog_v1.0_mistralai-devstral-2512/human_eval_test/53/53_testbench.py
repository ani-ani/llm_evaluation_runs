import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

CLK_NS = 10
MAX_CYCLES = 1000
DATA_WIDTH = 16

def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def test_addition(dut, x_val, y_val):
    dut.x.value = clamp_to_width(x_val, DATA_WIDTH)
    dut.y.value = clamp_to_width(y_val, DATA_WIDTH)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    await wait_for_done(dut)
    result = int(dut.result.value)
    expected = (x_val + y_val) & ((1 << DATA_WIDTH) - 1)
    return result, expected

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_add_module(dut):
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        await Timer(100, units='ns')

    test_cases = [
        (0, 1, 1, "zero and one"),
        (1, 0, 1, "one and zero"),
        (2, 3, 5, "small addition"),
        (5, 7, 12, "simple sum"),
        (7, 5, 12, "reversed"),
    ]

    passed = 0
    failed = 0

    # Fixed test cases
    for x_val, y_val, expected, desc in test_cases:
        cocotb.log.info(f"Test: {desc} ({x_val} + {y_val})")
        try:
            result, expected_calc = await test_addition(dut, x_val, y_val)
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            if expected_calc != expected:
                raise TestFailure(f"Calculated expected {expected_calc}, test case {expected}")
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1

    # Random test cases
    cocotb.log.info("Running 100 random tests...")
    for i in range(100):
        x_val = random.randint(0, 1000)
        y_val = random.randint(0, 1000)
        expected = (x_val + y_val) & ((1 << DATA_WIDTH) - 1)
        try:
            result, expected_calc = await test_addition(dut, x_val, y_val)
            if result != expected:
                raise TestFailure(f"Random test {i}: Expected {expected}, got {result} ({x_val} + {y_val})")
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1

    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")
    else:
        cocotb.log.info(f"All {passed} tests passed!")

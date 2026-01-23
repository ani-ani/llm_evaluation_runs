import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

# Configuration
DATA_WIDTH = 32
FRAC_BITS = 16
MAX_CONVEYORS = 3
CLK_PERIOD_NS = 10
TIMEOUT_MS = 5000

# Helper functions
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    try:
        return int(value)
    except ValueError:
        return default

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def float_to_fixed(f, frac_bits=FRAC_BITS):
    return int(f * (1 << frac_bits))

def fixed_to_float(fixed, frac_bits=FRAC_BITS):
    return fixed / (1 << frac_bits)

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def start_computation(dut):
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

@cocotb.test(timeout_time=TIMEOUT_MS, timeout_unit="ms")
async def test_moving_walkways(dut):
    """Test with provided sample inputs."""
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    await reset_dut(dut)

    test_cases = [
        {
            "input": "60.0 0.0 50.0 170.0\n3\n40.0 0.0 0.0 0.0\n5.0 20.0 5.0 170.0\n95.0 0.0 95.0 80.0\n",
            "expected": 168.7916512460
        },
        {
            "input": "60.0 0.0 50.0 170.0\n3\n40.0 0.0 0.0 0.0\n5.0 20.0 5.0 170.0\n95.0 0.0 95.0 100.0\n",
            "expected": 163.5274740179
        },
        {
            "input": "0.0 1.0 4.0 1.0\n1\n0.0 0.0 4.0 0.0\n",
            "expected": 3.7320508076
        },
        {
            "input": "0.0 1.0 10.0 1.0\n2\n1.0 0.0 2.0 3.0\n6.0 1.0 4.0 1.0\n",
            "expected": 10.0000000000
        }
    ]

    for i, tc in enumerate(test_cases):
        dut._log.info(f"Test case {i+1}")
        lines = tc["input"].strip().split('\n')
        A_x, A_y, B_x, B_y = map(float, lines[0].split())
        N = int(lines[1])
        conveyors = [list(map(float, lines[2+j].split())) for j in range(N)]

        # Set coordinates
        dut.a_x.value = float_to_fixed(A_x)
        dut.a_y.value = float_to_fixed(A_y)
        dut.b_x.value = float_to_fixed(B_x)
        dut.b_y.value = float_to_fixed(B_y)

        for j in range(MAX_CONVEYORS):
            if j < N:
                x1, y1, x2, y2 = conveyors[j]
                getattr(dut, f'c{j}_x1').value = float_to_fixed(x1)
                getattr(dut, f'c{j}_y1').value = float_to_fixed(y1)
                getattr(dut, f'c{j}_x2').value = float_to_fixed(x2)
                getattr(dut, f'c{j}_y2').value = float_to_fixed(y2)
                getattr(dut, f'c{j}_valid').value = 1
            else:
                getattr(dut, f'c{j}_valid').value = 0
                getattr(dut, f'c{j}_x1').value = 0
                getattr(dut, f'c{j}_y1').value = 0
                getattr(dut, f'c{j}_x2').value = 0
                getattr(dut, f'c{j}_y2').value = 0

        await start_computation(dut)
        await wait_for_done(dut)

        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Result undefined for test {i+1}")

        result_fixed = int(dut.result.value)
        result_float = fixed_to_float(result_fixed)
        expected = tc["expected"]
        error = abs(result_float - expected)
        if error > 1e-4:
            raise TestFailure(f"Test {i+1}: expected {expected}, got {result_float}, error {error}")

        dut._log.info(f"Test {i+1} passed: {result_float}")

    dut._log.info("All tests passed!")
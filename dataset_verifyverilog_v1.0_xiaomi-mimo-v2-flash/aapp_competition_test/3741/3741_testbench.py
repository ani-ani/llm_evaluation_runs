import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

DATA_WIDTH = 64
MAX_NODES = 16
CLK_NS = 10
MAX_CYCLES = 5000

# Helper Functions
def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except ValueError:
        return default

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
    if has_signal(dut, 'start'):
        dut.start.value = 0
    if has_signal(dut, 'wr_en'):
        dut.wr_en.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def load_data(dut, values):
    """Load list of values into DUT memory."""
    dut._log.info(f"Loading {len(values)} values...")
    dut.num_nodes.value = len(values)
    for i, v in enumerate(values):
        dut.data_in.value = clamp_to_width(v, DATA_WIDTH)
        dut.wr_en.value = 1
        await RisingEdge(dut.clk)
        dut.wr_en.value = 0
        await RisingEdge(dut.clk) # Small gap

@cocotb.test(timeout_time=10, timeout_unit="ms")
async def test_shortest_cycle(dut):
    # Check for required signals
    required = ['clk', 'rst_n', 'start', 'wr_en', 'data_in', 'num_nodes', 'result', 'done']
    for sig in required:
        if not has_signal(dut, sig):
            raise TestFailure(f"Missing signal: {sig}")

    # Start Clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)

    # Test Cases (Scaled to 16 nodes max)
    # Case 1: Input from problem example 2 (5 nodes -> 3 cycle)
    # Values: 5, 12, 9, 16, 48
    test_cases = [
        {
            "vals": [5, 12, 9, 16, 48],
            "expected": 3,
            "desc": "Problem Ex 2: Triangle (5, 12, 9)"
        },
        {
            "vals": [3, 6, 28, 9],
            "expected": 4,
            "desc": "Problem Ex 1: Square cycle"
        },
        {
            "vals": [1, 2, 4, 8],
            "expected": -1,
            "desc": "Problem Ex 3: No cycle"
        },
        {
            "vals": [7, 7, 7], # All share bits
            "expected": 3,
            "desc": "Triangle via bit 0"
        },
        {
            "vals": [1, 2],
            "expected": -1,
            "desc": "Just an edge"
        }
    ]

    passed = 0
    failed = 0

    for tc in test_cases:
        dut._log.info(f"Running Test: {tc['desc']}")
        
        # Load inputs
        await load_data(dut, tc['vals'])

        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for done
        try:
            await wait_for_done(dut)
        except TestFailure as e:
            dut._log.error(f"Timeout for {tc['desc']}")
            failed += 1
            continue

        # Read Result
        result_val = int(dut.result.value)
        
        # Convert expected -1 to unsigned max (common for -1 in Verilog)
        expected_val = tc['expected']
        if expected_val == -1:
            # Assuming 16-bit result, -1 is 0xFFFF = 65535
            expected_val = 65535

        if result_val == expected_val:
            dut._log.info(f"PASS: {tc['desc']} -> Result {result_val}")
            passed += 1
        else:
            dut._log.error(f"FAIL: {tc['desc']} -> Expected {expected_val}, Got {result_val}")
            failed += 1

    if failed > 0:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")

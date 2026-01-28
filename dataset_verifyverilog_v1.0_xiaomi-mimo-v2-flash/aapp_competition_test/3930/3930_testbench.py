import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
ARRAY_SIZE = 16
CLK_NS = 10
MAX_CYCLES = 300

# MANDATORY HELPERS
def is_value_defined(v):
    try:
        int(v)
        return True
    except (ValueError, TypeError):
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except (ValueError, TypeError):
        return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits - 1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(v, bits):
    max_val = (1 << bits) - 1
    min_val = 0 if bits == 16 else -(1 << bits) if bits == 8 else 0
    if bits == 8:
        return min(max_val, max(min_val, v))
    else:
        return v & max_val

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
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

async def write_array(dut, vals, width=DATA_WIDTH):
    for i in range(ARRAY_SIZE):
        if i < len(vals):
            val = clamp_to_width(vals[i], width)
        else:
            val = 0
        dut.arr[i].value = val

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_count_powers(dut):
    # Setup
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        await Timer(100, units='ns')

    # Test cases: (arr, len, k, expected_count, description)
    test_cases = [
        ([2, 2, 2, 2], 4, 2, 8, "Example 1: powers of 2"),
        ([3, -6, -3, 12], 4, -3, 3, "Example 2: powers of -3"),
        ([1, 1, 1, 1], 4, 1, 10, "k=1, all sums are powers of 1"),
        ([1, 1, 1, 1], 4, -1, 16, "k=-1, powers are 1,-1"),
        ([1, 2, 3, 4], 4, 1, 10, "k=1"),
        ([1], 1, 2, 1, "Single element 1 = 2^0"),
        ([2], 1, 2, 1, "Single element 2 = 2^1"),
        ([0, 0, 0, 0], 4, 1, 10, "All zeros = 2^0 for k=1"),
        ([1, -1, 1, -1], 4, 1, 10, "Alternating 1,-1"),
        ([2, 2, 2], 3, 2, 6, "Partial array 2,2,2"),
        ([1, 2, 4, 8], 4, 2, 6, "Powers of 2 sum to powers of 2"),
        ([5], 1, 1, 1, "Single element 5 = 5^0 for k=1"),
        ([100], 1, 2, 0, "100 not a power of 2"),
    ]

    passed = 0
    failed = 0

    for i, (arr, length, k, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i + 1}: {desc}")
        cocotb.log.info(f"  Input: arr={arr}, len={length}, k={k}")
        cocotb.log.info(f"  Expected: {expected}")

        try:
            # Set inputs
            await write_array(dut, arr, DATA_WIDTH)
            if is_seq:
                dut.len.value = length
                dut.k.value = clamp_to_width(k, 3)  # 3-bit signed, clamp to range -4..3
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                # Combinational
                dut.len.value = length
                dut.k.value = k
                await Timer(100, units='ns')

            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")

            result = int(dut.result.value)
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")

            cocotb.log.info(f"  Result: {result} ✓")
            passed += 1

        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1

    if failed:
        raise TestFailure(f"{failed} test(s) failed out of {passed + failed}")
    cocotb.log.info(f"All {passed} tests passed!")

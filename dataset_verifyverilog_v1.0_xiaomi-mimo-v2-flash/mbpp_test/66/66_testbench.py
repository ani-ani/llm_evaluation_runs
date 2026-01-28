import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helpers
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

# Global params
DATA_WIDTH = 8
ARRAY_SIZE = 8
CLK_NS = 10
MAX_CYCLES = 100

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def write_array(dut, vals, width):
    # Write to individual elements arr[0] to arr[7]
    for i in range(ARRAY_SIZE):
        val = vals[i] if i < len(vals) else 0
        # Convert to signed 8-bit representation if needed
        signed_val = to_signed(val, width)
        getattr(dut, f'arr_{i}').value = clamp_to_width(signed_val, width)

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_pos_count(dut):
    # Check for sequential signals
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # For combinational, just wait a bit
        await Timer(100, units='ns')

    test_cases = [
        ([1, -2, 3, -4], 2, "Mixed positive/negative"),
        ([3, 4, 5, -1], 3, "Mostly positive"),
        ([1, 2, 3, 4], 4, "All positive"),
        ([-1, -2, -3, -4], 0, "All negative"),
        ([0, 0, 0, 0], 4, "Zeros (non-negative)"),
        ([127, -128, 64, -64], 2, "Extreme values")
    ]

    passed = 0
    failed = 0

    for i, (inp, exp, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Write array
            await write_array(dut, inp, DATA_WIDTH)
            # Set len (expand to 8 if shorter)
            actual_len = min(len(inp), 8)
            if has_signal(dut, 'len'):
                dut.len.value = actual_len

            if is_seq:
                # Start computation
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                # Wait for done
                await wait_for_done(dut)
                # Check result
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result undefined")
                result = int(dut.result.value)
            else:
                # Combinational, just read
                await Timer(10, units='ns')
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result undefined")
                result = int(dut.result.value)

            if result != exp:
                raise TestFailure(f"Expected {exp}, got {result}")
            passed += 1

        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1

    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed+failed}")
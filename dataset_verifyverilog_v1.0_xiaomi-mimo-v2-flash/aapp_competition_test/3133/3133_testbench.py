import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Constants
DATA_WIDTH = 4  # 4-bit node IDs
STEP_BITS = 8
ARRAY_SIZE = 16
CLK_NS = 10
MAX_CYCLES = 300  # 256 + overhead

# Helper functions
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

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

# Write 16-element array to separate signals
async def write_transitions(dut, name, vals):
    for i in range(ARRAY_SIZE):
        attr_name = f"{name}_{i}"
        if has_signal(dut, attr_name):
            getattr(dut, attr_name).value = clamp_to_width(vals[i], DATA_WIDTH)

# Write tower visibility to 16 separate signals
async def write_tower_visibility(dut, vals):
    for i in range(ARRAY_SIZE):
        attr_name = f"tower_{i}"
        if has_signal(dut, attr_name):
            getattr(dut, attr_name).value = vals[i] & 1

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

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_pisa_navigation(dut):
    # Start clock
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        await Timer(100, units='ns')

    # Test cases
    # Case 1: indistinguishable (3 nodes, same tower visibility)
    test_cases = [
        # (alice_start, bob_start, left_trans, right_trans, tower_vis, expected_steps, desc)
        (
            1, 2,
            [1, 0, 0] + [0]*13,  # left_0=1, left_1=0, left_2=0
            [2, 2, 1] + [0]*13,   # right_0=2, right_1=2, right_2=1
            [1, 0, 0] + [0]*13,   # tower_0=1, tower_1=0, tower_2=0
            -1,  # -1 means indistinguishable
            "indistinguishable"
        ),
        # Case 2: step 0 (different tower visibility)
        (
            0, 1,
            [1] + [0]*15,
            [1] + [0]*15,
            [1] + [0]*15,
            0,
            "step 0"
        ),
        # Case 3: step 1
        (
            1, 2,
            [1, 2, 0] + [0]*13,
            [2, 0, 1] + [0]*13,
            [0, 1, 1] + [0]*13,
            1,
            "step 1"
        ),
    ]

    passed = 0
    failed = 0

    for i, (alice_start, bob_start, left_vals, right_vals, tower_vals, expected_steps, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Write inputs
            if has_signal(dut, 'alice_start'):
                dut.alice_start.value = clamp_to_width(alice_start, DATA_WIDTH)
            if has_signal(dut, 'bob_start'):
                dut.bob_start.value = clamp_to_width(bob_start, DATA_WIDTH)

            await write_transitions(dut, 'left_trans', left_vals)
            await write_transitions(dut, 'right_trans', right_vals)
            await write_tower_visibility(dut, tower_vals)

            # Start search
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(100, units='ns')

            # Check result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")

            result = int(dut.result.value)
            valid = (result >> 15) & 1
            steps = result & 0xFF

            if expected_steps == -1:
                # Expect indistinguishable: valid should be 1 and steps=255 or similar
                if valid != 1:
                    raise TestFailure(f"Expected valid flag=1 for indistinguishable case, got {valid}")
                cocotb.log.info(f"Case {desc}: Found result after {steps} steps (indistinguishable)")
            else:
                if valid != 1:
                    raise TestFailure(f"Expected valid flag=1, got {valid}")
                if steps != expected_steps:
                    raise TestFailure(f"Expected {expected_steps} steps, got {steps}")
            passed += 1

        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1

    if failed:
        raise TestFailure(f"{failed} tests failed")

    cocotb.log.info(f"All {passed} tests passed")
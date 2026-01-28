import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
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

# Configuration
DATA_WIDTH = 8
CLK_NS = 10
MAX_CYCLES = 200

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=100):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_iscube(dut):
    # Check if sequential
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational mode: just wait a bit
        pass

    # Test cases: (input_a, expected_is_cube, description)
    test_cases = [
        (1, 1, "1 is 1^3"),
        (2, 0, "2 is not a cube"),
        (-1, 1, "-1 is (-1)^3"),
        (64, 1, "64 is 4^3"),
        (-64, 1, "-64 is (-4)^3"),
        (0, 1, "0 is 0^3"),
        (125, 1, "125 is 5^3"),
        (-125, 1, "-125 is (-5)^3"),
        (127, 0, "127 is not a cube"),
        (-128, 0, "-128 is not a cube"),
        (180, 0, "180 (wrapped) is not a cube"),
        (100, 0, "100 is not a cube"),
        (8, 1, "8 is 2^3"),
        (-8, 1, "-8 is (-2)^3")
    ]

    passed = 0
    failed = 0

    for i, (a_val, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc} (a={a_val})")
        try:
            # Clamp input to 8-bit signed for assignment
            a_clamped = to_signed(a_val, 8) & 0xFF
            dut.a.value = a_clamped

            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut, max_cycles=50)
            else:
                await Timer(1, units='ns')

            if not is_value_defined(dut.is_cube.value):
                raise TestFailure("is_cube is undefined")
            
            result = int(dut.is_cube.value)
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            passed += 1

        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1

    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")

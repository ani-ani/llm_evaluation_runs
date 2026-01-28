import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 36
RESULT_WIDTH = 1
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================
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

def to_signed(val, bits):
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    if val < 0:
        return val + (1 << bits)
    return val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# ============================================================================
# ARRAY ACCESS HELPERS
# ============================================================================
async def write_grid(dut, input_str):
    lines = [line.strip() for line in input_str.splitlines() if line.strip() != '']
    if len(lines) != 6:
        raise TestFailure(f"Input must have 6 lines, got {len(lines)}")
    grid_flat = 0
    for i in range(6):
        if len(lines[i]) != 6:
            raise TestFailure(f"Line {i} must have 6 characters, got {len(lines[i])}")
        for j in range(6):
            if lines[i][j] == '#':
                grid_flat |= (1 << (i * 6 + j))
            elif lines[i][j] != '.':
                raise TestFailure(f"Invalid character at ({i},{j}): {lines[i][j]}")
    dut.grid_flat.value = grid_flat

async def read_result(dut):
    if not is_value_defined(dut.can_fold.value):
        raise TestFailure("can_fold is undefined (X/Z)")
    return int(dut.can_fold.value)

# ============================================================================
# MAIN TEST
# ============================================================================
@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_can_fold(dut):
    if not has_signal(dut, 'grid_flat'):
        raise TestFailure("DUT missing 'grid_flat' signal")
    if not has_signal(dut, 'can_fold'):
        raise TestFailure("DUT missing 'can_fold' signal")

    test_cases = [
        ("......\n......\n######\n......\n......\n......\n", 0, "cannot fold"),
        ("......\n#.....\n####..\n#.....\n......\n......\n", 1, "can fold"),
        ("..##..\n...#..\n..##..\n...#..\n......\n......\n", 0, "cannot fold"),
        ("......\n...#..\n...#..\n..###.\n..#...\n......\n", 1, "can fold"),
    ]

    passed = 0
    failed = 0
    for i, (input_str, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        try:
            await write_grid(dut, input_str)
            await Timer(100, units='ns')  # Wait for combinational propagation
            result = await read_result(dut)
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1

    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
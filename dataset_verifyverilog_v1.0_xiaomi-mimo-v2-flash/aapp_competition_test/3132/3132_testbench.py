import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helpers
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

# Convert grid string to 64-bit int (row-major)
def grid_to_int(grid_str):
    # grid_str is list of strings like ['xx.', 'xxx', '...']
    bits = 0
    for r in range(len(grid_str)):
        for c in range(len(grid_str[0])):
            idx = r * 8 + c
            if grid_str[r][c] == 'x':
                bits |= (1 << idx)
    return bits

# Extract squares from output bits
def extract_squares(r1, c1, s1, r2, c2, s2):
    return (int(r1), int(c1), int(s1)), (int(r2), int(c2), int(s2))

# Verify if two squares cover all 'x's in grid
def verify_coverage(grid_str, sq1, sq2):
    rows = len(grid_str)
    cols = len(grid_str[0])
    covered = [[False]*cols for _ in range(rows)]
    # Mark sq1
    r1, c1, s1 = sq1
    for r in range(r1, r1+s1):
        for c in range(c1, c1+s1):
            if r < rows and c < cols:
                covered[r][c] = True
    # Mark sq2
    r2, c2, s2 = sq2
    for r in range(r2, r2+s2):
        for c in range(c2, c2+s2):
            if r < rows and c < cols:
                covered[r][c] = True
    # Check all 'x's are covered
    for r in range(rows):
        for c in range(cols):
            if grid_str[r][c] == 'x' and not covered[r][c]:
                return False
    return True

async def wait_for_done(dut, max_cycles=1000):
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

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_two_squares(dut):
    # Assume dut has inputs: clk, rst_n, start, grid_in (64-bit)
    # Outputs: r1, c1, s1, r2, c2, s2, done
    
    # Setup clock if seq
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational - still need to handle signals
        pass

    # Test cases
    test_cases = [
        {
            "grid": [
                "xx.",
                "xxx",
                "..."
            ],
            "desc": "Sample 1"
        },
        {
            "grid": [
                "xx....",
                "xx.xxx",
                "...xxx",
                "...xxx"
            ],
            "desc": "Sample 2"
        },
        {
            "grid": [
                ".....",
                "xxx..",
                "xxxx.",
                "xxxx.",
                ".xxx."
            ],
            "desc": "Sample 3"
        }
    ]

    passed = 0
    failed = 0

    for idx, tc in enumerate(test_cases):
        cocotb.log.info(f"Test {idx+1}: {tc['desc']}")
        try:
            # Prepare input
            grid_int = grid_to_int(tc['grid'])
            
            if is_seq:
                dut.grid_in.value = grid_int
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                # Combinational: set input and wait
                dut.grid_in.value = grid_int
                await Timer(100, units='ns')
            
            # Read outputs
            r1 = safe_int(dut.r1.value)
            c1 = safe_int(dut.c1.value)
            s1 = safe_int(dut.s1.value)
            r2 = safe_int(dut.r2.value)
            c2 = safe_int(dut.c2.value)
            s2 = safe_int(dut.s2.value)
            
            # Validate ranges
            if not all(0 <= x < 8 for x in [r1, c1, s1, r2, c2, s2]):
                raise TestFailure(f"Outputs out of range: {r1},{c1},{s1} | {r2},{c2},{s2}")
            if s1 == 0 or s2 == 0:
                raise TestFailure("Size cannot be 0")
            if r1+s1 > 8 or c1+s1 > 8 or r2+s2 > 8 or c2+s2 > 8:
                raise TestFailure(f"Square out of bounds: {r1},{c1},{s1} | {r2},{c2},{s2}")

            # Verify coverage
            sq1 = (r1, c1, s1)
            sq2 = (r2, c2, s2)
            if not verify_coverage(tc['grid'], sq1, sq2):
                raise TestFailure(f"Squares {sq1} and {sq2} do not cover all 'x' in grid")
            
            cocotb.log.info(f"PASS: Found squares {sq1} and {sq2}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1

    if failed:
        raise TestFailure(f"{failed} test(s) failed")

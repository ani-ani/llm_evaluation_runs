import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Constants for scaling
MAX_SEQ_LEN = 64
DATA_WIDTH = 4
DIST_WIDTH = 6
CLK_NS = 10
MAX_CYCLES = 300

# Helper functions
def is_value_defined(v):
    try:
        int(v); return True
    except ValueError:
        return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, v))

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    if has_signal(dut, 'seq_we'): dut.seq_we.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def load_sequence(dut, digits):
    """Load sequence digits into the module"""
    dut.seq_len.value = clamp_to_width(len(digits), 4)
    await RisingEdge(dut.clk)
    
    for d in digits:
        dut.seq_din.value = clamp_to_width(d, DATA_WIDTH)
        dut.seq_we.value = 1
        await RisingEdge(dut.clk)
    
    dut.seq_we.value = 0
    await RisingEdge(dut.clk)

async def check_result(dut, exp_found, exp_a=None, exp_b=None, exp_c=None, exp_n=None, exp_m=None):
    """Check output signals"""
    found = int(dut.found.value)
    
    if found != exp_found:
        raise TestFailure(f"Expected found={exp_found}, got {found}")
    
    if found == 1 and exp_found == 1:
        a = int(dut.a_out.value)
        b = int(dut.b_out.value)
        c = int(dut.c_out.value)
        n = int(dut.n_out.value)
        m = int(dut.m_out.value)
        
        if exp_a is not None and a != exp_a:
            raise TestFailure(f"Expected a={exp_a}, got {a}")
        if exp_b is not None and b != exp_b:
            raise TestFailure(f"Expected b={exp_b}, got {b}")
        if exp_c is not None and c != exp_c:
            raise TestFailure(f"Expected c={exp_c}, got {c}")
        if exp_n is not None and n != exp_n:
            raise TestFailure(f"Expected n={exp_n}, got {n}")
        if exp_m is not None and m != exp_m:
            raise TestFailure(f"Expected m={exp_m}, got {m}")
        
        cocotb.log.info(f"Found correlation: {a}({n}){b}({m}){c}")

async def run_test(dut, digits, exp_found, exp_a=None, exp_b=None, exp_c=None, exp_n=None, exp_m=None, desc=""):
    """Complete test for one sequence"""
    cocotb.log.info(f"Test: {desc} (len={len(digits)})")
    
    # Reset
    await reset_dut(dut)
    
    # Load sequence
    await load_sequence(dut, digits)
    
    # Start search
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion
    await wait_for_done(dut)
    
    # Check result
    await check_result(dut, exp_found, exp_a, exp_b, exp_c, exp_n, exp_m)

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_triple_correlation(dut):
    # Check for required signals
    required_signals = ['clk', 'rst_n', 'start', 'seq_len', 'seq_din', 'seq_we', 'done', 'found', 'a_out', 'b_out', 'c_out', 'n_out', 'm_out']
    missing = [s for s in required_signals if not has_signal(dut, s)]
    if missing:
        raise TestFailure(f"Missing signals: {missing}")
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    # Test case 1: Example with triple correlation 4(1)4(3)3
    # For feasibility, we use scaled version with first 32 digits
    test_digits_1 = [4, 7, 9, 5, 9, 3, 5, 0, 0, 1, 7, 8, 5, 0, 2, 6, 3, 5, 4, 4, 4, 6, 3, 3, 2, 7, 1, 8, 7, 8, 7, 6]
    await run_test(dut, test_digits_1, exp_found=1, exp_a=4, exp_b=4, exp_c=3, exp_n=1, exp_m=3,
                   desc="Example sequence with 4(1)4(3)3 correlation")
    
    # Test case 2: No correlation (simple increasing sequence)
    test_digits_2 = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
    # Clamp to 4-bit (digits 0-9)
    test_digits_2_clamped = [min(d, 9) for d in test_digits_2]
    await run_test(dut, test_digits_2_clamped, exp_found=0, desc="No correlation sequence")
    
    # Test case 3: Very short sequence (should find nothing)
    test_digits_3 = [1, 2, 3, 4]
    await run_test(dut, test_digits_3, exp_found=0, desc="Short sequence with no correlation")
    
    # Test case 4: Sequence with known pattern 1(2)3(4)5
    # This tests a specific pattern: every time 1 is 2 positions before 3,
    # 4 positions after 3 is 5
    test_digits_4 = [1, 9, 3, 9, 5, 1, 9, 3, 9, 5, 1, 9, 3, 9, 5, 1]
    await run_test(dut, test_digits_4, exp_found=1, exp_a=1, exp_b=3, exp_c=5, exp_n=2, exp_m=4,
                   desc="Pattern 1(2)3(4)5")
    
    cocotb.log.info("All tests passed!")

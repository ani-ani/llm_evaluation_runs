import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
N = 16
DATA_WIDTH = 8
RESULT_WIDTH = 16
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

# ============================================================================
# MANDATORY HELPER FUNCTIONS
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
# ALGORITHM HELPER
# ============================================================================
def compute_moves(s1_vals, s2_vals):
    prev_pos = 0
    prev_neg = 0
    moves = 0
    for a, b in zip(s1_vals, s2_vals):
        diff = b - a
        pos = diff if diff > 0 else 0
        neg = -diff if diff < 0 else 0
        inc_pos = max(0, pos - prev_pos)
        inc_neg = max(0, neg - prev_neg)
        moves += inc_pos + inc_neg
        prev_pos = pos
        prev_neg = neg
    return moves

# ============================================================================
# MAIN TEST
# ============================================================================
@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_string_puzzle_solver(dut):
    # Detect signals
    has_clk = has_signal(dut, 'clk')
    has_start = has_signal(dut, 'start')
    has_done = has_signal(dut, 'done')
    
    if has_clk:
        # Sequential module
        cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    # Define test cases
    test_cases = [
        ("hello", "teams"),
        ("aacccaaaa", "bbbbbbbbb"),
        ("abc", "abc"),  # same
        ("aaaa", "bbbb"),  # all increase by 1
        ("zzzz", "yyyy"),  # all decrease by 1
    ]
    
    for s1_str, s2_str in test_cases:
        # Convert to ASCII values and pad to N with 'a' (97)
        s1_vals = [ord(c) for c in s1_str]
        s2_vals = [ord(c) for c in s2_str]
        # Pad with 'a' (97) to length N
        s1_vals += [97] * (N - len(s1_vals))
        s2_vals += [97] * (N - len(s2_vals))
        
        expected = compute_moves(s1_vals, s2_vals)
        
        dut._log.info(f"Testing '{s1_str}' -> '{s2_str}' (padded) expected {expected}")
        
        # Write inputs
        for i in range(N):
            dut.s1[i].value = s1_vals[i]
            dut.s2[i].value = s2_vals[i]
        
        if has_clk:
            # Start computation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            # Wait for done
            cycles = 0
            while not (is_value_defined(dut.done.value) and int(dut.done.value) == 1):
                await RisingEdge(dut.clk)
                cycles += 1
                if cycles > MAX_CYCLES:
                    raise TestFailure("Timeout waiting for done")
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined")
            result = int(dut.result.value)
        else:
            # Combinational - wait for propagation
            await Timer(100, units='ns')
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined")
            result = int(dut.result.value)
        
        if result != expected:
            raise TestFailure(f"Expected {expected}, got {result}")
        else:
            dut._log.info(f"  PASS: result = {result}")
    
    dut._log.info("All tests passed")
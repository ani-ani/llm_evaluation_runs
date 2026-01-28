import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
N = 4                    # Number of positions
DATA_WIDTH = 2           # Bits per position
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    """Safely convert cocotb value to int, returning default if X/Z."""
    try:
        return int(value)
    except ValueError:
        return default

def has_signal(dut, name):
    """Check if DUT has a signal with given name."""
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    """Clamp value to fit within specified bit width."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# ============================================================================
# SEQUENTIAL MODULE HELPERS
# ============================================================================

async def reset_dut(dut, cycles=2):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    """Wait for done signal with timeout."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def start_computation(dut):
    """Pulse start signal for one cycle."""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# COMPUTE EXPECTED AVERAGE (for verification)
# ============================================================================

def compute_steps(state):
    """Compute number of steps for a given state (list of bits, leftmost first)."""
    steps = 0
    while True:
        k = sum(state)
        if k == 0:
            break
        state[k-1] = 1 - state[k-1]  # flip k-th coin from left
        steps += 1
    return steps

def compute_expected_average(pattern_str):
    """Compute expected average for a pattern string of length N."""
    # Count '?' to determine number of completions
    q = pattern_str.count('?')
    total = 0
    # Enumerate all completions
    for i in range(1 << q):
        state = []
        idx = 0
        for c in pattern_str:
            if c == '?':
                bit = (i >> idx) & 1
                idx += 1
                state.append(bit)
            elif c == 'H':
                state.append(1)
            else:  # 'T'
                state.append(0)
        steps = compute_steps(state)
        total += steps
    return total / (1 << q)

# ============================================================================
# PATTERN ENCODING
# ============================================================================

def encode_pattern(pattern_str):
    """Encode pattern string (length N) into 2*N-bit integer."""
    # Mapping: 'T' -> 0, 'H' -> 1, '?' -> 2 (binary 10)
    value = 0
    for i, c in enumerate(pattern_str):
        if c == 'T':
            enc = 0
        elif c == 'H':
            enc = 1
        elif c == '?':
            enc = 2
        else:
            enc = 0  # default
        value |= enc << (2 * i)
    return value

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_average_operations(dut):
    """Test the average_operations module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases: (pattern string, description)
    test_cases = [
        ("TTTT", "All T"),
        ("HTTT", "First H, rest T"),
        ("?TTT", "First ?, rest T"),
        ("??TT", "First two ?, rest T"),
        ("HHHH", "All H"),
        ("????", "All ?"),
    ]
    
    passed = 0
    failed = 0
    
    for pattern_str, description in test_cases:
        cocotb.log.info(f"Testing: {pattern_str} ({description})")
        
        # Compute expected value
        expected = compute_expected_average(pattern_str)
        
        # Encode pattern
        pattern_value = encode_pattern(pattern_str)
        cocotb.log.info(f"  Encoded pattern = 0x{pattern_value:X}")
        
        # Apply pattern
        dut.pattern.value = pattern_value
        
        # Start computation
        await start_computation(dut)
        
        # Wait for done
        await wait_for_done(dut)
        
        # Read result (fixed-point Q16.16)
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Result is undefined (X/Z)")
        
        result_fixed = int(dut.result.value)
        result_float = result_fixed / 65536.0  # 2^16
        
        # Check with tolerance
        tolerance = 1e-6
        if abs(result_float - expected) > max(tolerance * abs(expected), tolerance):
            cocotb.log.error(f"  FAIL: expected {expected}, got {result_float}")
            failed += 1
        else:
            cocotb.log.info(f"  PASS: result = {result_float} (fixed=0x{result_fixed:X})")
            passed += 1
        
        # Wait one cycle before next test
        await RisingEdge(dut.clk)
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
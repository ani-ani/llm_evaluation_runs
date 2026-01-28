import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
N = 4  # String length
DATA_WIDTH = 5  # Bits per character (0-25)
COUNT_WIDTH = 4  # Bits for count (max 10)
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

# ============================================================================
# MANDATORY HELPER FUNCTIONS
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

def to_signed(val, bits):
    """Convert unsigned integer to signed (two's complement)."""
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    """Convert signed integer to unsigned for Verilog assignment."""
    if val < 0:
        return val + (1 << bits)
    return val

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
    if value < 0:
        # Handle signed values
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
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
    raise TestFailure(f'Timeout: done not asserted after {max_cycles} cycles')

async def start_computation(dut):
    """Pulse start signal for one cycle."""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# TEST CASES
# ============================================================================

def str_to_vals(s):
    """Convert lowercase string to list of 5-bit values (0-25)."""
    return [ord(c) - ord('a') for c in s]

# Precomputed test cases: (input_string, expected_count)
# The counts were manually verified for N=4.
test_cases = [
    ('aaaa', 10),   # All substrings are palindromes
    ('abca', 4),    # Only single characters
    ('aabb', 9),    # 4 singles + 2 double palindromes + 2 triple almost + 1 quadruple almost
    ('abcd', 4),    # Only singles (no swaps can make palindrome for longer substrings)
]

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit='ms')
async def test_almost_palindrome_counter(dut):
    """Test the almost palindrome substring counter module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    passed = 0
    failed = 0
    
    for i, (input_str, expected) in enumerate(test_cases):
        cocotb.log.info(f'Test {i+1}: {input_str!r} -> expected {expected}')
        
        try:
            # Assign input string to char_in array
            values = str_to_vals(input_str)
            for idx, val in enumerate(values):
                # Clamp to DATA_WIDTH (should already be within 0-25, but for safety)
                clamped = clamp_to_width(val, DATA_WIDTH)
                if has_signal(dut, f'char_in_{idx}'):
                    getattr(dut, f'char_in_{idx}').value = clamped
                else:
                    # Assume array style
                    dut.char_in[idx].value = clamped
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.count.value):
                raise TestFailure('Count output is undefined (X/Z)')
            
            result = int(dut.count.value)
            
            if result != expected:
                raise TestFailure(f'Expected {expected}, got {result}')
            
            cocotb.log.info(f'  PASS: count = {result}')
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f'  FAIL: {e}')
            failed += 1
    
    cocotb.log.info(f'{"="*50}')
    cocotb.log.info(f'Results: {passed}/{passed+failed} tests passed')
    
    if failed > 0:
        raise TestFailure(f'{failed} tests failed')

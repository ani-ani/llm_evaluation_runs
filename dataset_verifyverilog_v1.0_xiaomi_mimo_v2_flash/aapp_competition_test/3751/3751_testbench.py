import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 5      # 5 bits per character (0-7)
ARRAY_SIZE = 8      # Max 8 characters
LEN_WIDTH = 4       # len is 4 bits
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000   # Max cycles for processing

# ============================================================================
# HELPER FUNCTIONS (mandatory)
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
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# ============================================================================
# ARRAY ACCESS HELPERS
# ============================================================================

async def write_char_array(dut, values):
    """Write characters to individual ports char_0..char_7."""
    for i in range(ARRAY_SIZE):
        if i < len(values):
            val = values[i]
        else:
            val = 0  # default 0 for unused
        port_name = f'char_{i}'
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = clamp_to_width(val, DATA_WIDTH)
        else:
            # Fallback to indexed array if exists
            if has_signal(dut, 'char_array'):
                dut.char_array[i].value = clamp_to_width(val, DATA_WIDTH)
            else:
                raise TestFailure(f"Cannot find port {port_name}")

async def read_result(dut):
    """Read result and done signals."""
    result = safe_int(dut.result.value, 0) if is_value_defined(dut.result.value) else None
    done = safe_int(dut.done.value, 0) if is_value_defined(dut.done.value) else None
    return result, done

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
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_obfuscation_check(dut):
    """Main test for obfuscation check module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases: (string, expected_result, description)
    # String is lowercase letters 'a' to 'h' (0-7)
    test_cases = [
        ("abacaba", 1, "Original example YES"),
        ("abc", 1, "Sequential order YES"),
        ("acb", 0, "Out of order NO"),
        ("aab", 1, "Duplicate a then b YES"),
        ("aba", 1, "a,b,a YES"),
        ("abba", 1, "a,b,b,a YES"),
        ("ab", 1, "a,b YES"),
        ("ba", 0, "b,a NO"),
        ("a", 1, "Single a YES"),
        ("b", 0, "Single b NO"),
        ("aa", 1, "a,a YES"),
        ("bb", 0, "b,b NO"),
        ("abcdefgh", 1, "All 8 letters YES"),
        ("abca", 1, "a,b,c,a YES"),
        ("abcb", 1, "a,b,c,b YES"),
        ("abcc", 1, "a,b,c,c YES"),
        ("abacab", 1, "a,b,a,c,a,b YES"),
        ("ac", 0, "a,c NO"),
        ("ad", 0, "a,d NO"),
        ("c", 0, "c alone NO"),
        ("abbbd", 0, "a,b,b,b,d NO"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (string, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description} - '{string}'")
        
        # Convert string to list of integer values (0-7)
        values = [ord(c) - ord('a') for c in string]
        length = len(values)
        
        # Write characters to DUT
        await write_char_array(dut, values)
        
        # Write length
        if has_signal(dut, 'len'):
            dut.len.value = length
        else:
            raise TestFailure("Signal 'len' not found")
        
        # Start computation
        await start_computation(dut)
        
        # Wait for done
        await wait_for_done(dut)
        
        # Read result
        result, _ = await read_result(dut)
        
        if result != expected:
            cocotb.log.error(f"  FAIL: expected {expected}, got {result}")
            failed += 1
        else:
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")

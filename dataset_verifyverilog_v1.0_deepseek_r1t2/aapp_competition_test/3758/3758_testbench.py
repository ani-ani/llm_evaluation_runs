import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
FIELD_SIZE = 16
RESULT_WIDTH = 16
CLK_PERIOD_NS = 10
MAX_CYCLES = 50000  # Large timeout for the complex state machine

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
    """Clamp value to fit within specified bit width (unsigned)."""
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
# FIELD ENCODING
# ============================================================================

def encode_field(field_str):
    """Encode a field string (up to 16 chars) into a 128-bit integer."""
    field_str = field_str.ljust(FIELD_SIZE, '.')
    result = 0
    for i, char in enumerate(field_str[:FIELD_SIZE]):
        result |= ord(char) << (i * 8)
    return result

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_packman_time(dut):
    """Test packman time calculation module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases: (field_string, expected_time, description)
    test_cases = [
        ("*..P*P*", 3, "Example 1 - 7 cells"),
        (".**PP.*P.*", 2, "Example 2 - 10 cells"),
        ("**P.*..*..P..*.*P**", 7, "19 cells truncated to 16"),
        ("P**.*P*P*P**", 3, "12 cells"),
        (".*P*P**P**.**P...", 3, "17 cells truncated to 16"),
        ("P*", 1, "Minimal case 1"),
        ("P**", 2, "Three asterisks"),
        ("*P", 1, "Minimal case 2"),
        ("*.*P*", 2, "Sparse"),
        ("PPPPPPPPPPPPPPPP", 0, "Only Packmen"),
        ("****************", 0, "Only asterisks (but no Packmen - invalid but test)"),
        ("..P.P*.P*.P...PPP...P*....*..*.**......*P.*P.....**P...*P*", 9, "58 cells truncated"),
        (".**PP.*P.*", 2, "Duplicate test"),
        ("*..P*P*", 3, "Duplicate test"),
        ("P*", 1, "Minimal"),
        ("*P", 1, "Minimal"),
        ("P**", 2, "Simple"),
        (".*P*", 2, "Sparse"),
        ("***.*.*..P", 9, "10 cells"),
        ("P***..PPP..P*.P", 3, "15 cells"),
        ("*.*....*P......", 8, "15 cells"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (field_str, expected, description) in enumerate(test_cases):
        # Skip if field has no asterisks or no Packmen (invalid per problem)
        if '*' not in field_str or 'P' not in field_str:
            cocotb.log.info(f"Test {i+1}: SKIPPED - {description} (no asterisks or Packmen)")
            continue
        
        cocotb.log.info(f"Test {i+1}: {description}")
        cocotb.log.info(f"  Field: {field_str}")
        cocotb.log.info(f"  Expected: {expected}")
        
        try:
            # Encode field and write to DUT
            field_encoded = encode_field(field_str)
            dut.field.value = field_encoded
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure(f"Result is undefined (X/Z)")
            
            result = int(dut.result.value)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        
        # Reset between tests
        await reset_dut(dut)
    
    # Summary
    cocotb.log.info(f"{'='*60}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
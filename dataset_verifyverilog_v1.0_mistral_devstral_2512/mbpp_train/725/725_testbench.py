import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
STR_LEN = 64
CHAR_WIDTH = 8
OUT_SUBSTR_LEN = 16
OUT_COUNT_MAX = 4
CLK_PERIOD_NS = 10
MAX_CYCLES = 200

# ASCII values
QUOTE = 34  # '"'

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
# ARRAY WRITE/READ HELPERS
# ============================================================================

async def write_string(dut, text, max_len=STR_LEN):
    """Write string to input array as ASCII bytes."""
    # Convert string to list of ASCII values
    ascii_vals = [ord(c) for c in text]
    
    # Pad with zeros if shorter than max_len
    while len(ascii_vals) < max_len:
        ascii_vals.append(0)
    
    # Write to array - element by element
    for i in range(max_len):
        if has_signal(dut, f'input_str_{i}'):
            getattr(dut, f'input_str_{i}').value = ascii_vals[i]
        elif has_signal(dut, 'input_str'):
            dut.input_str[i].value = ascii_vals[i]
        else:
            raise TestFailure(f"Cannot find input_str[{i}] or input_str_{i}")

async def read_substring(dut, prefix, index, length):
    """Read a substring from output array."""
    result = []
    for i in range(length):
        # Try different access patterns
        port_name = f'{prefix}_{i}'
        if has_signal(dut, port_name):
            val = int(getattr(dut, port_name).value)
        else:
            raise TestFailure(f"Cannot find {port_name}")
        
        if val > 0:
            result.append(chr(val))
    return ''.join(result)

# ============================================================================
# SEQUENTIAL HELPERS
# ============================================================================

async def reset_dut(dut, cycles=2):
    """Reset the DUT."""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut):
    """Wait for done signal with timeout."""
    for cycle in range(MAX_CYCLES):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {MAX_CYCLES} cycles")

async def start_computation(dut):
    """Pulse start signal."""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_extract_quotation(dut):
    """Test quotation extraction module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (input_text, expected_substrings, description)
    test_cases = [
        ('Cortex "A53" Based "multi" tasking "Processor"', 
         ['A53', 'multi', 'Processor'], 
         "Three substrings with words between quotes"),
        ('Cast your "favorite" entertainment "apps"', 
         ['favorite', 'apps'], 
         "Two substrings"),
        ('Watch content "4k Ultra HD" resolution with "HDR 10" Support', 
         ['4k Ultra HD', 'HDR 10'], 
         "Substrings with spaces"),
        ("Watch content '4k Ultra HD' resolution with 'HDR 10' Support", 
         [], 
         "Single quotes only - should find none"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (input_text, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: {description}")
        cocotb.log.info(f"Input: '{input_text}'")
        cocotb.log.info(f"Expected: {expected}")
        
        try:
            # Write input string
            await write_string(dut, input_text)
            
            # Write input length
            dut.input_len.value = clamp_to_width(len(input_text), 6)
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read results
            count = int(dut.count.value)
            
            actual = []
            for j in range(min(count, OUT_COUNT_MAX)):
                # Get substring length
                len_signal_name = f'found_len{j}'
                substr_len = int(getattr(dut, len_signal_name).value)
                
                # Get substring
                if substr_len > 0:
                    substr = await read_substring(dut, f'found{j}', j, substr_len)
                    actual.append(substr)
            
            cocotb.log.info(f"Actual: {actual}")
            cocotb.log.info(f"Count: {count}")
            
            # Verify
            if actual != expected:
                raise TestFailure(f"Mismatch: expected {expected}, got {actual}")
            
            cocotb.log.info("  PASS")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
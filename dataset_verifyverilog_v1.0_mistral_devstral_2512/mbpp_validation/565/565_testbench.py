import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
ARRAY_SIZE = 16
CLK_PERIOD_NS = 10
MAX_CYCLES = 100

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

async def reset_dut(dut):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    dut.start.value = 0
    
    for _ in range(2):
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

async def feed_string(dut, test_string, max_len=16):
    """Feed characters of string one per cycle."""
    # Pad string to 16 characters
    padded = test_string.ljust(max_len, '\x00')
    
    for i, char in enumerate(padded):
        dut.char_in.value = ord(char) if char != '\x00' else 0
        await RisingEdge(dut.clk)

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_char_splitter(dut):
    """Test the character splitter module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases
    test_cases = [
        ('python', ['p', 'y', 't', 'h', 'o', 'n']),
        ('Name', ['N', 'a', 'm', 'e']),
        ('program', ['p', 'r', 'o', 'g', 'r', 'a', 'm']),
    ]
    
    passed = 0
    failed = 0
    
    for i, (test_str, expected_chars) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: splitting '{test_str}' (length {len(test_str)})")
        
        try:
            # Set string length
            dut.str_len.value = len(test_str)
            
            # Start computation
            await start_computation(dut)
            
            # Feed characters while computing
            # Start feeding on next cycle
            await RisingEdge(dut.clk)
            
            # Feed string over cycles
            for cycle, char in enumerate(test_str):
                dut.char_in.value = ord(char)
                await RisingEdge(dut.clk)
            
            # Feed dummy values for remaining cycles to fill to 16
            for _ in range(len(test_str), 16):
                dut.char_in.value = 0
                await RisingEdge(dut.clk)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read output array
            results = []
            for j in range(len(test_str)):
                if is_value_defined(dut.out_chars[j].value):
                    char_val = int(dut.out_chars[j].value)
                    results.append(chr(char_val))
                else:
                    results.append(None)
            
            # Verify results
            for j, (actual, expected) in enumerate(zip(results, expected_chars)):
                if actual != expected:
                    raise TestFailure(f"Position {j}: expected '{expected}', got '{actual}'")
            
            # Check that valid is high
            if not is_value_defined(dut.valid.value) or int(dut.valid.value) != 1:
                raise TestFailure("Valid signal not asserted")
            
            cocotb.log.info(f"  PASS: Output = {results}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
            
        # Reset between tests
        await reset_dut(dut)
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
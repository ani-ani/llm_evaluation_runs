import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
NUM_STRINGS = 8
STRING_LEN = 8
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

def clamp_to_width(value, bits):
    """Clamp value to fit within specified bit width (unsigned)."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

def has_signal(dut, name):
    """Check if DUT has a signal with given name."""
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

# ============================================================================
# ARRAY/STRING WRITE HELPER
# ============================================================================

def pack_string_to_ports(dut, str_idx, string_val):
    """Write a string to the character ports, truncating or padding to 8 chars."""
    # Pad/truncate to exactly 8 characters
    padded = string_val.ljust(STRING_LEN, ' ')[:STRING_LEN]
    
    for char_idx, char in enumerate(padded):
        port_name = f"str_{str_idx}_char_{char_idx}"
        if has_signal(dut, port_name):
            # Convert char to ASCII
            ascii_val = ord(char)
            getattr(dut, port_name).value = clamp_to_width(ascii_val, DATA_WIDTH)

# ============================================================================
# RESET AND DONE WAIT
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

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_reverse_pair_counter(dut):
    """Test the reverse pair counter with multiple string lists."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (string_list, expected_pair_count, description)
    # Strings are padded to 8 characters with spaces
    test_cases = [
        (["julia", "best", "tseb", "for", "ailuj"], 2, "Test 1: julia/ailuj and best/tseb"),
        (["geeks", "best", "for", "skeeg"], 1, "Test 2: geeks/skeeg"),
        (["makes", "best", "sekam", "for", "rof"], 2, "Test 3: makes/sekam and for/rof"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (string_list, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: {description}")
        cocotb.log.info(f"  Input: {string_list}")
        
        try:
            # Clear all input ports first
            for s in range(NUM_STRINGS):
                for c in range(STRING_LEN):
                    port_name = f"str_{s}_char_{c}"
                    if has_signal(dut, port_name):
                        getattr(dut, port_name).value = 0
            
            # Write each string to the ports
            for idx, s in enumerate(string_list):
                pack_string_to_ports(dut, idx, s)
            
            # Set number of valid strings
            dut.num_strings.value = len(string_list)
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.pair_count.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result = int(dut.pair_count.value)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: pair_count = {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")

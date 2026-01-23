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
    """Clamp value to fit within specified bit width (unsigned)."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# ============================================================================
# ARRAY ACCESS HELPERS
# ============================================================================

def string_to_bytes(s):
    """Convert string to list of ASCII byte values."""
    return [ord(c) for c in s]

def write_string_to_ports(dut, s):
    """Write string to individual port interface."""
    bytes_list = string_to_bytes(s)
    
    # Write each character to corresponding port
    for i in range(min(len(bytes_list), 16)):
        port_name = f"str_{i}"
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = clamp_to_width(bytes_list[i], DATA_WIDTH)
        else:
            raise TestFailure(f"Cannot find port: {port_name}")
    
    # Write length
    if has_signal(dut, 'str_len'):
        dut.str_len.value = len(bytes_list)
    else:
        raise TestFailure("Cannot find str_len port")

def read_result_from_ports(dut):
    """Read result from individual port interface."""
    results = []
    
    for i in range(16):
        port_name = f"result_{i}"
        if has_signal(dut, port_name):
            val = getattr(dut, port_name).value
            if is_value_defined(val):
                byte_val = int(val)
                if byte_val != 0:  # Only append non-null bytes
                    results.append(chr(byte_val))
        else:
            raise TestFailure(f"Cannot find port: {port_name}")
    
    return ''.join(results)

# ============================================================================
# SEQUENTIAL MODULE HELPERS
# ============================================================================

async def reset_dut(dut):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    
    for _ in range(2):
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
    """Pulse start signal for one cycle."""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_string_to_lower(dut):
    """Test string to lowercase conversion."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases
    test_cases = [
        ("InValid", "invalid", "Mixed case with capital I and V"),
        ("TruE", "true", "Mixed case with T and E"),
        ("SenTenCE", "sentence", "Multiple capitals"),
        ("ABC", "abc", "All capitals"),
        ("xyz", "xyz", "Already lowercase"),
        ("A1B2C3", "a1b2c3", "With numbers"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (input_str, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        cocotb.log.info(f"  Input: '{input_str}' -> Expected: '{expected}'")
        
        try:
            # Write input string
            write_string_to_ports(dut, input_str)
            
            # Start computation
            await start_computation(dut)
            
            # Wait for completion
            await wait_for_done(dut)
            
            # Read result
            result = read_result_from_ports(dut)
            
            # Verify
            if result != expected:
                raise TestFailure(f"Expected '{expected}', got '{result}'")
            
            cocotb.log.info(f"  PASS: result = '{result}'")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        
        # Wait one cycle between tests
        await RisingEdge(dut.clk)
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")

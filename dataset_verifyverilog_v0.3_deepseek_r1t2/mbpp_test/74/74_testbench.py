import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
ARRAY_SIZE = 8
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

def string_to_ascii_packed(s, max_len=8):
    """Convert string to 64-bit packed ASCII (8 chars, LSB first)."""
    s = s[:max_len].ljust(max_len, '\x00')
    result = 0
    for i, c in enumerate(s):
        result |= (ord(c) << (i * 8))
    return result

async def write_array(dut, array_name, values, element_width):
    """Write values to array, handling individual ports."""
    for i, val in enumerate(values):
        port_name = f"{array_name}_{i}"
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = clamp_to_width(val, element_width)
        else:
            raise TestFailure(f"Cannot find array port: {port_name}")

async def read_signal(dut, signal_name):
    """Safely read a signal."""
    sig = getattr(dut, signal_name)
    if is_value_defined(sig.value):
        return int(sig.value)
    return 0

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

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_pattern_checker(dut):
    """Main test function for pattern checker."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases
    # Format: (colors_list, patterns_list, expected_result, description)
    test_cases = [
        (["red", "green", "green"], ["a", "b", "b"], True, "Test 1: Basic match"),
        (["red", "green", "greenn"], ["a", "b", "b"], False, "Test 2: Mismatched colors for same pattern"),
        (["red", "green", "greenn"], ["a", "b"], False, "Test 3: Length mismatch (different lengths)"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (colors_list, patterns_list, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        
        try:
            # Convert strings to packed ASCII and pattern codes
            num_elem = len(colors_list)
            
            # Validate lengths match
            if len(colors_list) != len(patterns_list):
                # Expected to fail per test case logic
                # In our design, this is handled by not starting with mismatched arrays
                # We'll set num_elements to the smaller one to simulate the check
                num_elem = min(len(colors_list), len(patterns_list))
            
            # Prepare packed values
            packed_colors = [string_to_ascii_packed(c) for c in colors_list]
            pattern_codes = [ord(p[0]) if len(p) > 0 else 0 for p in patterns_list]
            
            # Pad arrays to 8 elements
            while len(packed_colors) < 8:
                packed_colors.append(0)
            while len(pattern_codes) < 8:
                pattern_codes.append(0)
            
            # Write colors
            await write_array(dut, 'colors', packed_colors, 64)
            
            # Write patterns
            await write_array(dut, 'patterns', pattern_codes, 8)
            
            # Set num_elements
            dut.num_elements.value = num_elem
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            result = await read_signal(dut, 'result')
            
            # Verify
            if bool(result) == expected:
                cocotb.log.info(f"  PASS: Result={result}, Expected={expected}")
                passed += 1
            else:
                cocotb.log.error(f"  FAIL: Result={result}, Expected={expected}")
                failed += 1
                
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")

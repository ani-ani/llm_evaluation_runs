import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
MAX_LEN = 16
CHAR_WIDTH = 8
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
    """Clamp value to fit within specified bit width (unsigned)."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# ============================================================================
# ARRAY ACCESS HELPERS
# ============================================================================

async def write_string_array(dut, array_name, test_string):
    """Write string to array as ASCII codes."""
    # Ensure string fits within MAX_LEN
    test_string = test_string[:MAX_LEN]
    
    # Write each character as ASCII
    for i, char in enumerate(test_string):
        ascii_val = ord(char)
        # Find the array element
        try:
            arr = getattr(dut, array_name)
            arr[i].value = ascii_val
        except (AttributeError, TypeError):
            # Try individual ports
            port_name = f"{array_name}_{i}"
            if has_signal(dut, port_name):
                getattr(dut, port_name).value = ascii_val
            else:
                raise TestFailure(f"Cannot find array port: {array_name}[{i}]")
    
    # Pad remaining with zeros
    for i in range(len(test_string), MAX_LEN):
        try:
            arr = getattr(dut, array_name)
            arr[i].value = 0
        except (AttributeError, TypeError):
            port_name = f"{array_name}_{i}"
            if has_signal(dut, port_name):
                getattr(dut, port_name).value = 0

async def read_string_array(dut, array_name, length):
    """Read array and convert to string."""
    result = []
    
    try:
        arr = getattr(dut, array_name)
        for i in range(length):
            if is_value_defined(arr[i].value):
                ascii_val = int(arr[i].value)
                if ascii_val > 0:
                    result.append(chr(ascii_val))
    except (AttributeError, TypeError):
        # Try individual ports
        for i in range(length):
            port_name = f"{array_name}_{i}"
            if has_signal(dut, port_name):
                val = getattr(dut, port_name).value
                if is_value_defined(val):
                    ascii_val = int(val)
                    if ascii_val > 0:
                        result.append(chr(ascii_val))
    
    return ''.join(result)

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
async def test_move_num(dut):
    """Test move_num function: move all digits to end of string."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases: (input_string, expected_output, description)
    test_cases = [
        ("I1love143you55three3000thousand", "Iloveyouthreethousand1143553000", "Test 1: Mixed content"),
        ("Avengers124Assemble", "AvengersAssemble124", "Test 2: Digits in middle"),
        ("Its11our12path13to14see15things16do17things", "Itsourpathtoseethingsdothings11121314151617", "Test 3: Multiple digits"),
        ("abc123", "abc123", "Test 4: No change needed"),
        ("123abc", "abc123", "Test 5: All digits first"),
        ("abc", "abc", "Test 6: No digits"),
        ("123", "123", "Test 7: Only digits"),
        ("", "", "Test 8: Empty string"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (input_str, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        cocotb.log.info(f"  Input: '{input_str}'")
        cocotb.log.info(f"  Expected: '{expected}'")
        
        try:
            # Skip empty string test if hardware doesn't support it
            if len(input_str) == 0:
                if not is_value_defined(dut.len_in):
                    cocotb.log.warning(f"  SKIP: Empty string not supported by hardware")
                    continue
            
            # Write input string
            await write_string_array(dut, 'str_in', input_str)
            
            # Write length
            dut.len_in.value = len(input_str)
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read length out
            if not is_value_defined(dut.len_out.value):
                raise TestFailure(f"len_out is undefined (X/Z)")
            
            output_len = int(dut.len_out.value)
            
            # Read output string
            result_str = await read_string_array(dut, 'str_out', output_len)
            
            # Verify
            if result_str != expected:
                raise TestFailure(f"Expected '{expected}', got '{result_str}'")
            
            cocotb.log.info(f"  Result: '{result_str}' [PASS]")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*60}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
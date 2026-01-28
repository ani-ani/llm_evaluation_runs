import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
MAX_STRING_LEN = 16
CLK_PERIOD_NS = 10
MAX_CYCLES = 50

# ASCII values
UNDERSCORE = 95
LOWERCASE_A = 97
LOWERCASE_Z = 122
UPPERCASE_A = 65
UPPERCASE_Z = 90

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

def string_to_array(s):
    """Convert Python string to list of ASCII values."""
    return [ord(c) for c in s]

def array_to_string(arr):
    """Convert list of ASCII values to Python string."""
    return ''.join(chr(v) for v in arr if v > 0)

def snake_to_camel_expected(s):
    """Python reference implementation."""
    parts = s.split('_')
    return ''.join(p.capitalize() for p in parts)

# ============================================================================
# ARRAY ACCESS HELPERS
# ============================================================================

async def write_string_array(dut, array_name, values):
    """Write string values to array."""
    # Try indexed array first
    try:
        arr = getattr(dut, array_name)
        for i in range(MAX_STRING_LEN):
            if i < len(values):
                arr[i].value = clamp_to_width(values[i], DATA_WIDTH)
            else:
                arr[i].value = 0
        return
    except (AttributeError, TypeError):
        pass
    
    # Try individual ports (input_str_0, input_str_1, ...)
    for i in range(MAX_STRING_LEN):
        port_name = f"{array_name}_{i}"
        if has_signal(dut, port_name):
            val = values[i] if i < len(values) else 0
            getattr(dut, port_name).value = clamp_to_width(val, DATA_WIDTH)
        else:
            raise TestFailure(f"Cannot find array port: {array_name}[{i}] or {port_name}")

async def read_string_array(dut, array_name, expected_len):
    """Read string values from array."""
    results = []
    
    # Try indexed array first
    try:
        arr = getattr(dut, array_name)
        for i in range(MAX_STRING_LEN):
            if is_value_defined(arr[i].value):
                results.append(int(arr[i].value))
            else:
                results.append(0)
        return results
    except (AttributeError, TypeError):
        pass
    
    # Try individual ports
    for i in range(MAX_STRING_LEN):
        port_name = f"{array_name}_{i}"
        if has_signal(dut, port_name):
            val = getattr(dut, port_name).value
            if is_value_defined(val):
                results.append(int(val))
            else:
                results.append(0)
        else:
            results.append(0)
    
    return results

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
async def test_snake_to_camel(dut):
    """Test snake_case to camelCase conversion."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases: (input_string, expected_output_string)
    test_cases = [
        ('python_program', 'PythonProgram'),
        ('python_language', 'PythonLanguage'),
        ('programming_language', 'ProgrammingLanguage'),
        ('simple', 'Simple'),
        ('test_case', 'TestCase'),
        ('a_b_c', 'ABC'),
        ('alreadyCamel', 'AlreadyCamel'),  # No underscores
        ('single', 'Single'),
        ('under_score', 'UnderScore'),
        ('trailing_', 'Trailing'),  # Trailing underscore
        ('_leading', 'Leading'),  # Leading underscore
    ]
    
    passed = 0
    failed = 0
    
    for i, (input_str, expected_str) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: '{input_str}' -> '{expected_str}'")
        
        try:
            # Prepare input
            input_array = string_to_array(input_str)
            input_len = len(input_array)
            
            # Write inputs
            await write_string_array(dut, 'input_str', input_array)
            
            # Write input length
            if has_signal(dut, 'input_len'):
                dut.input_len.value = input_len
            else:
                cocotb.log.warning("input_len signal not found, skipping length input")
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read results
            output_array = await read_string_array(dut, 'output_str', MAX_STRING_LEN)
            
            # Read output length
            output_len = 0
            if has_signal(dut, 'output_len'):
                if is_value_defined(dut.output_len.value):
                    output_len = int(dut.output_len.value)
            
            # Convert to string
            actual_str = array_to_string(output_array)
            
            # Trim to output_len if available
            if output_len > 0:
                actual_str = actual_str[:output_len]
            
            # Verify
            if actual_str != expected_str:
                raise TestFailure(
                    f"Mismatch: expected '{expected_str}' (len={len(expected_str)}), "
                    f"got '{actual_str}' (len={len(actual_str)})"
                )
            
            cocotb.log.info(f"  PASS: '{actual_str}'")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
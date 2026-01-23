import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# ============================================================================
# CONFIGURATION
# ============================================================================
MAX_CMD_LEN = 32
MAX_HISTORY = 8
CHAR_WIDTH = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

# ASCII values for common characters
ASCII_SPACE = 32
ASCII_HAT = 94  # '^'
ASCII_MINUS = 45
ASCII_DOT = 46
ASCII_A = 65
ASCII_Z = 90
ASCII_a = 97
ASCII_z = 122
ASCII_0 = 48
ASCII_9 = 57

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

# ============================================================================
# ARRAY ACCESS HELPERS
# ============================================================================

async def write_array(dut, array_name, values, element_width):
    """Write values to array, handling different interface styles."""
    # Try 2D array first
    try:
        arr = getattr(dut, array_name)
        for i, val in enumerate(values):
            arr[i].value = clamp_to_width(val, element_width)
        return
    except (AttributeError, TypeError):
        pass
    
    # Try individual ports (array_name_0, array_name_1, ...)
    for i, val in enumerate(values):
        port_name = f"{array_name}_{i}"
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = clamp_to_width(val, element_width)
        else:
            # Try indexed notation
            try:
                getattr(dut, f"{array_name}[{i}]").value = clamp_to_width(val, element_width)
            except:
                raise TestFailure(f"Cannot find array port: {array_name}[{i}] or {port_name}")

async def read_array(dut, array_name, size):
    """Read array values, handling different interface styles."""
    results = []
    
    # Try 2D array first
    try:
        arr = getattr(dut, array_name)
        for i in range(size):
            if is_value_defined(arr[i].value):
                results.append(int(arr[i].value))
            else:
                results.append(None)
        return results
    except (AttributeError, TypeError):
        pass
    
    # Try individual ports
    for i in range(size):
        port_name = f"{array_name}_{i}"
        if has_signal(dut, port_name):
            val = getattr(dut, port_name).value
            if is_value_defined(val):
                results.append(int(val))
            else:
                results.append(None)
        else:
            # Try indexed notation
            try:
                val = getattr(dut, f"{array_name}[{i}]").value
                if is_value_defined(val):
                    results.append(int(val))
                else:
                    results.append(None)
            except:
                results.append(None)
    
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
# TEST HELPER FUNCTIONS
# ============================================================================

def str_to_ascii_list(s):
    """Convert string to list of ASCII values."""
    return [ord(c) for c in s]

def ascii_list_to_str(ascii_list):
    """Convert list of ASCII values to string."""
    # Find first zero or None and truncate
    result = []
    for v in ascii_list:
        if v is None or v == 0:
            break
        result.append(chr(v))
    return ''.join(result)

async def setup_command(dut, cmd_str):
    """Setup a command for the DUT."""
    cmd_ascii = str_to_ascii_list(cmd_str)
    cmd_len = len(cmd_ascii)
    
    # Pad to MAX_CMD_LEN with zeros
    padded = cmd_ascii + [0] * (MAX_CMD_LEN - cmd_len)
    
    # Write to cmd_in array
    await write_array(dut, 'cmd_in', padded, CHAR_WIDTH)
    
    # Write cmd_len
    dut.cmd_len.value = cmd_len

async def get_result(dut):
    """Get the completed command from DUT."""
    out_len = int(dut.out_len.value)
    if out_len == 0:
        return ""
    
    cmd_out = await read_array(dut, 'cmd_out', out_len)
    # Convert to string
    result = ''.join([chr(v) for v in cmd_out if v is not None])
    return result

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_fish_shell(dut):
    """Main test for fish shell command history processor."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut, cycles=3)
    
    # Define test cases: each is (input_command, expected_output, description)
    # We adapt the sample test cases to fit our constraints
    test_cases = [
        # Sample 1 adapted
        ("python", "python", "First command"),
        ("p^ m.py", "python m.py", "Single up with prefix"),
        ("^ -n 1", "python m.py -n 1", "Multiple commands in history"),
        
        # Sample 2 adapted
        ("java", "java", "Second language"),
        ("^", "java", "One up after java"),
        ("^^^", "python", "Three ups (should wrap)"),
        ("^^^", "java", "Three ups again"),
        
        # Edge cases
        ("^^", "", "No history"),
        ("", "", "Empty command"),
        ("a^b", "ab", "Up with no match"),
        ("^python", "python", "Up at start"),
    ]
    
    # Track history for verification (list of commands)
    history = []
    
    passed = 0
    failed = 0
    
    for i, (input_cmd, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: {description}")
        cocotb.log.info(f"  Input: '{input_cmd}'")
        cocotb.log.info(f"  Expected: '{expected}'")
        
        try:
            # Setup input
            await setup_command(dut, input_cmd)
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut, max_cycles=256)  # Should complete quickly
            
            # Get result
            result = await get_result(dut)
            
            cocotb.log.info(f"  Got: '{result}'")
            
            # Verify
            if result != expected:
                raise TestFailure(f"Mismatch: expected '{expected}', got '{result}'")
            
            # Update history for next test (add result if not empty)
            if result:
                history.append(result)
                # Keep only last MAX_HISTORY commands
                if len(history) > MAX_HISTORY:
                    history = history[-MAX_HISTORY:]
            
            cocotb.log.info(f"  PASS")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")

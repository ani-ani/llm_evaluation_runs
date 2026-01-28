import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import re

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
STRING_LEN = 10
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

def python_date_convert(date_str):
    """Reference Python implementation."""
    return re.sub(r'(\d{4})-(\d{1,2})-(\d{1,2})', '\\3-\\2-\\1', date_str)

async def write_string(dut, signal_name, text, length):
    """Write string to array of 8-bit characters."""
    # Pad or truncate to fixed length
    text = text.ljust(length, ' ')[:length]
    
    # Try 2D array access
    try:
        arr = getattr(dut, signal_name)
        for i in range(length):
            arr[i].value = clamp_to_width(ord(text[i]), DATA_WIDTH)
        return
    except (AttributeError, TypeError):
        pass
    
    # Try individual ports
    for i in range(length):
        port_name = f"{signal_name}_{i}"
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = clamp_to_width(ord(text[i]), DATA_WIDTH)
        else:
            raise TestFailure(f"Cannot find {signal_name}[{i}] or {port_name}")

async def read_string(dut, signal_name, length):
    """Read array of 8-bit characters as string."""
    chars = []
    
    # Try 2D array access
    try:
        arr = getattr(dut, signal_name)
        for i in range(length):
            if is_value_defined(arr[i].value):
                chars.append(chr(int(arr[i].value)))
            else:
                chars.append('?')
        return ''.join(chars)
    except (AttributeError, TypeError):
        pass
    
    # Try individual ports
    for i in range(length):
        port_name = f"{signal_name}_{i}"
        if has_signal(dut, port_name):
            val = getattr(dut, port_name).value
            if is_value_defined(val):
                chars.append(chr(int(val)))
            else:
                chars.append('?')
        else:
            chars.append('?')
    
    return ''.join(chars)

async def reset_dut(dut, cycles=2):
    """Reset the DUT."""
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
async def test_date_format_converter(dut):
    """Test date format conversion from yyyy-mm-dd to dd-mm-yyyy."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases
    test_cases = [
        ("2026-01-02", "02-01-2026", "Single digit month/day"),
        ("2020-11-13", "13-11-2020", "Double digit month/day"),
        ("2021-04-26", "26-04-2021", "Standard conversion"),
        ("2023-12-31", "31-12-2023", "End of year"),
        ("2000-01-01", "01-01-2000", "Start of century"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (input_date, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        cocotb.log.info(f"  Input: {input_date}, Expected: {expected}")
        
        try:
            # Write input string
            await write_string(dut, 'date_in', input_date, STRING_LEN)
            
            # Start conversion
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read output string
            result = await read_string(dut, 'date_out', STRING_LEN)
            
            # Trim to exact length (remove padding)
            result = result.strip()
            
            if result != expected:
                raise TestFailure(f"Expected '{expected}', got '{result}'")
            
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
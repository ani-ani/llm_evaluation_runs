import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8          # Bit width of each character
ARRAY_SIZE = 64         # Max number of characters
RESULT_WIDTH = 1        # Result is 1 bit
CLK_PERIOD_NS = 10
MAX_CYCLES = 200        # Should be > ARRAY_SIZE + overhead

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
    
    # Try individual ports (arr_0, arr_1, ...)
    for i, val in enumerate(values):
        port_name = f"{array_name}_{i}"
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = clamp_to_width(val, element_width)
        else:
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
# HELPER TO CONVERT STRING TO ASCII LIST
# ============================================================================
def string_to_ascii(s):
    """Convert a Python string to list of ASCII values."""
    return [ord(c) for c in s]

# ============================================================================
# MAIN TEST
# ============================================================================
@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_goldbach_checker(dut):
    """Main test function for goldbach_checker."""
    
    # Detect if sequential (should be)
    is_sequential = has_signal(dut, 'clk') and has_signal(dut, 'done')
    if not is_sequential:
        raise TestFailure("DUT must be sequential with clk and done signals")
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (input_string, expected_result, description)
    test_cases = [
        ("10 3 7\n", 1, "Simple space-separated"),
        ("10   3   7\n", 1, "Multiple spaces"),
        ("314\n159 265\n358\n", 0, "Extra numbers (4 tokens)"),
        ("22 19 3\n", 1, "Even 22 = 19+3"),
        ("\n\n   60\n  \n  29\n  \n      31\n\t  \n\t  \n\t  \n\t  \n", 1, "Multi‑line with whitespace"),
        ("fred!\nsam!\ngeorge!\n", 0, "Non‑numeric characters"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (input_str, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        cocotb.log.info(f"  Input string: {repr(input_str)}")
        
        try:
            # Convert string to ASCII array
            ascii_list = string_to_ascii(input_str)
            if len(ascii_list) > ARRAY_SIZE:
                cocotb.log.warning(f"  Input length {len(ascii_list)} exceeds ARRAY_SIZE, truncating")
                ascii_list = ascii_list[:ARRAY_SIZE]
            
            len_val = len(ascii_list)
            
            # Write array elements individually
            for idx, ascii_val in enumerate(ascii_list):
                # Clamp to 8-bit (should already be 7-bit ASCII)
                dut.arr[idx].value = clamp_to_width(ascii_val, DATA_WIDTH)
            
            # Set length
            dut.len.value = len_val
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            actual = int(dut.result.value)
            
            if actual != expected:
                raise TestFailure(f"Expected {expected}, got {actual}")
            
            cocotb.log.info(f"  PASS: result = {actual}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        
        # Prepare for next test: reset
        await reset_dut(dut)
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
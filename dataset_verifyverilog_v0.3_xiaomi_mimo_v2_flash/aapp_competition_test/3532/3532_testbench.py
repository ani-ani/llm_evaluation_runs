import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
MAX_STR_LEN = 8
MAX_EXP_LEN = 4
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
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_string_explosion(dut):
    """Main test function for string explosion module."""
    
    # Detect module type
    is_sequential = has_signal(dut, 'clk')
    
    if is_sequential:
        # Start clock
        cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
        
        # Reset
        await reset_dut(dut)
    
    # Define test cases: (input_str, explosion_str, expected_result_str, expected_result_len, description)
    # Input strings and explosion strings are given as lists of integers (ASCII codes)
    test_cases = [
        # Test case 1: "aC4b" with "C4" -> "ab"
        (
            [0x61, 0x43, 0x34, 0x62],  # input_str = "aC4b"
            4,                          # input_len
            [0x43, 0x34],              # explosion_str = "C4"
            2,                          # explosion_len
            [0x61, 0x62],              # expected result_str = "ab"
            2,                          # expected result_len
            "aC4b with C4 -> ab"
        ),
        # Test case 2: "12ab" with "12ab" -> empty
        (
            [0x31, 0x32, 0x61, 0x62],  # input_str = "12ab"
            4,                          # input_len
            [0x31, 0x32, 0x61, 0x62],  # explosion_str = "12ab"
            4,                          # explosion_len
            [],                         # expected result_str (empty)
            0,                          # expected result_len
            "12ab with 12ab -> FRULA"
        ),
    ]
    
    passed = 0
    failed = 0
    
    for i, (input_vals, in_len, exp_vals, exp_len, expected_str, expected_len, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        
        try:
            # Write input_str
            await write_array(dut, 'input_str', input_vals, DATA_WIDTH)
            
            # Write explosion_str
            await write_array(dut, 'explosion_str', exp_vals, DATA_WIDTH)
            
            # Set lengths
            if has_signal(dut, 'input_len'):
                dut.input_len.value = in_len
            else:
                raise TestFailure("Signal 'input_len' not found")
            
            if has_signal(dut, 'explosion_len'):
                dut.explosion_len.value = exp_len
            else:
                raise TestFailure("Signal 'explosion_len' not found")
            
            if is_sequential:
                # Start computation and wait for done
                await start_computation(dut)
                await wait_for_done(dut)
            else:
                # Combinational - wait for propagation
                await Timer(100, units='ns')
            
            # Read result_len
            result_len_signal = getattr(dut, 'result_len')
            if not is_value_defined(result_len_signal.value):
                raise TestFailure("Result length is undefined (X/Z)")
            result_len = int(result_len_signal.value)
            
            # Read result_str
            result_str_vals = await read_array(dut, 'result_str', result_len)
            
            # Verify result_len
            if result_len != expected_len:
                raise TestFailure(f"Result length mismatch: expected {expected_len}, got {result_len}")
            
            # If expected_len > 0, verify result_str
            if expected_len > 0:
                for idx in range(expected_len):
                    if result_str_vals[idx] != expected_str[idx]:
                        raise TestFailure(f"Result string mismatch at position {idx}: expected {expected_str[idx]}, got {result_str_vals[idx]}")
            else:
                # Empty result, should be FRULA. Check that result_len is 0.
                if result_len != 0:
                    raise TestFailure(f"Expected empty result (FRULA), but got length {result_len}")
            
            cocotb.log.info(f"  PASS: result_len={result_len}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
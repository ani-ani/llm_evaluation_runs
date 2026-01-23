import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
MAX_S_LEN = 16
MAX_T_LEN = 16
CHAR_WIDTH = 8
CLK_PERIOD_NS = 10
TIMEOUT_CYCLES = 1000

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

async def wait_for_done(dut, max_cycles=TIMEOUT_CYCLES):
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
# PACKING FUNCTION FOR FLAT VECTORS
# ============================================================================

def pack_string(s, max_len):
    """Pack a string into a flat integer vector for Verilog."""
    flat = 0
    for i, c in enumerate(s):
        if i >= max_len:
            break
        flat |= ord(c) << (i * CHAR_WIDTH)
    return flat

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_find_fragment(dut):
    """Main test function for find_fragment module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases: (S, T, expected_count, expected_substring or None)
    # expected_substring is used only when expected_count == 1
    test_cases = [
        ("secretmessage", "boot", 1, "essa"),
        ("treetreetreetree", "wood", 3, None),
        ("oranges", "apples", 0, None),
        ("archipelago", "submarine", 2, None),
    ]
    
    passed = 0
    failed = 0
    
    for i, (S, T, expected_count, expected_substring) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: S='{S}', T='{T}'")
        
        # Pack strings into flat vectors
        flat_S = pack_string(S, MAX_S_LEN)
        flat_T = pack_string(T, MAX_T_LEN)
        len_S = len(S)
        len_T = len(T)
        
        # Set inputs
        dut.S_flat.value = flat_S
        dut.T_flat.value = flat_T
        dut.len_S.value = len_S
        dut.len_T.value = len_T
        
        # Start computation
        await start_computation(dut)
        
        # Wait for done
        await wait_for_done(dut)
        
        # Read outputs
        count = int(dut.count.value)
        
        # Read substring
        substring_chars = []
        for idx in range(MAX_T_LEN):
            if is_value_defined(dut.substring[idx].value):
                char_val = int(dut.substring[idx].value)
                if char_val != 0:
                    substring_chars.append(chr(char_val))
                else:
                    substring_chars.append('')
            else:
                substring_chars.append('')
        substring = ''.join(substring_chars)
        
        # Trim substring to len_T (since trailing zeros may be included)
        substring = substring[:len_T]
        
        # Verify count
        if count != expected_count:
            cocotb.log.error(f"  FAIL: expected count {expected_count}, got {count}")
            failed += 1
            continue
        
        # If count==1, verify substring
        if expected_count == 1:
            if expected_substring is None:
                cocotb.log.error(f"  FAIL: expected_substring is None but count==1")
                failed += 1
                continue
            if substring != expected_substring:
                cocotb.log.error(f"  FAIL: expected substring '{expected_substring}', got '{substring}'")
                failed += 1
                continue
        
        cocotb.log.info(f"  PASS: count={count}, substring='{substring}'")
        passed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
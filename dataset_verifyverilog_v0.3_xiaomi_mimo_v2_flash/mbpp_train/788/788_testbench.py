import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
STR_WIDTH = 128  # 16 chars × 8 bits
MAX_STR_LEN = 16
MAX_INPUTS = 8
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

def str_to_bits(s):
    """Convert string to 128-bit value (16 chars, LSB first)."""
    s = s[:MAX_STR_LEN].ljust(MAX_STR_LEN, '\x00')  # Truncate/pad to 16 chars
    result = 0
    for i, char in enumerate(s):
        result |= (ord(char) & 0xFF) << (i * 8)
    return result

def bits_to_str(bits):
    """Convert 128-bit value back to string."""
    chars = []
    for i in range(MAX_STR_LEN):
        char_code = (bits >> (i * 8)) & 0xFF
        if char_code != 0:
            chars.append(chr(char_code))
    return ''.join(chars)

def pack_string_array(strings):
    """Pack list of strings into array of 128-bit values."""
    return [str_to_bits(s) for s in strings]

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

async def write_string_array(dut, array_name, strings, max_elements):
    """Write string array to DUT (handles both packed and unpacked)."""
    packed_values = pack_string_array(strings)
    
    # Try packed array first
    if has_signal(dut, array_name):
        for i, val in enumerate(packed_values):
            if i < max_elements:
                getattr(dut, f"{array_name}[{i}]").value = val
        return
    
    # Try individual element ports
    for i, val in enumerate(packed_values):
        if i < max_elements:
            port_name = f"{array_name}_{i}"
            if has_signal(dut, port_name):
                getattr(dut, port_name).value = val
            else:
                raise TestFailure(f"Cannot find array port: {array_name}[{i}]")

async def read_string_array(dut, array_name, size):
    """Read string array from DUT."""
    results = []
    
    # Try packed array first
    try:
        for i in range(size):
            sig = getattr(dut, f"{array_name}[{i}]")
            if is_value_defined(sig.value):
                results.append(int(sig.value))
            else:
                results.append(0)
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
                results.append(0)
        else:
            results.append(0)
    
    return results

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_new_tuple(dut):
    """Test new_tuple module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (input_list, append_str, expected_output_list)
    test_cases = [
        (["WEB", "is"], "best", ["WEB", "is", "best"]),
        (["We", "are"], "Developers", ["We", "are", "Developers"]),
        (["Part", "is"], "Wrong", ["Part", "is", "Wrong"]),
    ]
    
    passed = 0
    failed = 0
    
    for i, (input_list, append_str, expected_list) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: {input_list} + '{append_str}'")
        
        try:
            # Write input strings
            for j, s in enumerate(input_list):
                dut.test_str_arr[j].value = str_to_bits(s)
            
            # Set input length
            dut.input_len.value = len(input_list)
            
            # Set append string
            dut.test_str.value = str_to_bits(append_str)
            
            # Start computation
            await start_computation(dut)
            await wait_for_done(dut)
            
            # Read output
            output_len = int(dut.output_len.value)
            
            if output_len != len(expected_list):
                raise TestFailure(f"Output length mismatch: expected {len(expected_list)}, got {output_len}")
            
            # Read and verify each output string
            for j in range(output_len):
                result_bits = int(dut.result_arr[j].value)
                result_str = bits_to_str(result_bits)
                expected_str = expected_list[j]
                
                if result_str != expected_str:
                    raise TestFailure(f"String {j}: expected '{expected_str}', got '{result_str}'")
            
            cocotb.log.info(f"  PASS: Output = {[bits_to_str(int(dut.result_arr[j].value)) for j in range(output_len)]}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")

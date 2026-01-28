import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=50):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def write_string(dut, s, max_len=16):
    """Write string to char_array and set char_count"""
    chars = list(s)
    # Pad to max_len with zeros
    while len(chars) < max_len:
        chars.append('\x00')
    
    # Write each character ASCII value to dut.char_array[i]
    for i, ch in enumerate(chars):
        ascii_val = ord(ch) if i < len(s) else 0
        # Ensure 8-bit width
        ascii_val = ascii_val & 0xFF
        if has_signal(dut, 'char_array') and hasattr(dut.char_array, '__iter__'):
            dut.char_array[i].value = ascii_val
    
    # Set char_count (4-bit)
    count = len(s)
    if count > max_len:
        count = max_len
    if has_signal(dut, 'char_count'):
        dut.char_count.value = clamp_to_width(count, 4)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_digitSum(dut):
    """Test the digitSum module with various strings"""
    
    # Check if sequential
    is_seq = has_signal(dut, 'clk')
    
    if is_seq:
        # Setup clock and reset
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    
    # Test cases: (input_string, expected_sum, description)
    test_cases = [
        ("", 0, "empty string"),
        ("abAB", 131, "mixed case"),
        ("abcCd", 67, "simple uppercase C"),
        ("helloE", 69, "single uppercase E"),
        ("woArBld", 131, "multiple uppercase"),
        ("aAaaaXa", 153, "lowercase with X"),
        (" How are yOu?", 151, "with spaces and punctuation"),
        ("You arE Very Smart", 327, "longer string"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (test_str, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc} - String: '{test_str}'")
        
        try:
            if is_seq:
                # Write input
                await write_string(dut, test_str)
                
                # Start processing
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                await wait_for_done(dut)
                
                # Read result
                result = int(dut.result.value)
            else:
                # Combinational - direct test
                await Timer(100, units='ns')
                result = int(dut.result.value)
            
            # Verify
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            cocotb.log.info(f"  PASS: result={result}")
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} of {len(test_cases)} tests failed")
    
    cocotb.log.info(f"All {passed} tests passed!")

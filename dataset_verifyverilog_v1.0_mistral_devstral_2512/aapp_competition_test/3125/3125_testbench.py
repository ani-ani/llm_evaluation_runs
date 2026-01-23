import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

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
    """Clamp value to fit within specified bit width."""
    max_val = (1 << bits) - 1
    if value < 0:
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# ============================================================================
# ARRAY ACCESS HELPERS
# ============================================================================

def string_to_bytes(s, max_len=8):
    """Convert string to list of byte values, padding with zeros."""
    bytes_list = []
    for i in range(max_len):
        if i < len(s):
            bytes_list.append(ord(s[i]))
        else:
            bytes_list.append(0)
    return bytes_list

def bytes_to_string(bytes_list):
    """Convert list of byte values to string, stopping at null."""
    chars = []
    for b in bytes_list:
        if b == 0:
            break
        chars.append(chr(b))
    return ''.join(chars)

def pack_string_to_64bit(s):
    """Pack string into 64-bit integer (8 characters)."""
    bytes_list = string_to_bytes(s, 8)
    result = 0
    for i, b in enumerate(bytes_list):
        result |= b << (i * 8)
    return result

# ============================================================================
# TESTBENCH
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_encoding_checker(dut):
    """Main test for encoding checker module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.i_str.value = 0
    dut.o_str.value = 0
    
    for _ in range(3):
        await RisingEdge(dut.clk)
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        # (input_I, input_O, expected_valid, expected_a_plus, expected_a_minus, description)
        ("a+b-c", "a-b+d-c", 1, "-", "+d-", "Test case 1: simple encoding"),
        ("knuth-morris-pratt", "knuthmorrispratt", 1, "<any>", "<empty>", "Test case 2: empty encoding"),
        ("d+-trouble", "doubletrouble", 1, "<empty>", "ouble", "Test case 3: multiple possibilities"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (input_I, input_O, exp_valid, exp_plus, exp_minus, description) in enumerate(test_cases):
        cocotb.log.info(f"Running test {i+1}: {description}")
        
        # Pack strings into 64-bit values
        i_packed = pack_string_to_64bit(input_I)
        o_packed = pack_string_to_64bit(input_O)
        
        # Set inputs
        dut.i_str.value = i_packed
        dut.o_str.value = o_packed
        dut.start.value = 1
        
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 100
        for _ in range(timeout):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                break
        else:
            cocotb.log.error(f"Test {i+1}: Timeout waiting for done")
            failed += 1
            continue
        
        # Check results
        if not is_value_defined(dut.valid.value):
            cocotb.log.error(f"Test {i+1}: Valid signal undefined")
            failed += 1
            continue
        
        actual_valid = int(dut.valid.value)
        
        if actual_valid != exp_valid:
            cocotb.log.error(f"Test {i+1}: Expected valid={exp_valid}, got {actual_valid}")
            failed += 1
            continue
        
        if exp_valid:
            # Read a_plus and a_minus as 64-bit values
            a_plus_val = int(dut.a_plus.value) if is_value_defined(dut.a_plus.value) else 0
            a_minus_val = int(dut.a_minus.value) if is_value_defined(dut.a_minus.value) else 0
            
            # Convert back to strings for comparison
            a_plus_str = bytes_to_string([(a_plus_val >> (j*8)) & 0xFF for j in range(8)])
            a_minus_str = bytes_to_string([(a_minus_val >> (j*8)) & 0xFF for j in range(8)])
            
            # Special handling for <any> and <empty>
            if exp_plus == "<any>":
                # For <any>, we expect either <any> or any other valid encoding
                if a_plus_str not in ["<any>", ""]:  # Allow <any> or empty
                    cocotb.log.warning(f"Test {i+1}: a_plus returned {a_plus_str}, expected <any>")
            elif a_plus_str != exp_plus:
                cocotb.log.error(f"Test {i+1}: a_plus mismatch. Expected '{exp_plus}', got '{a_plus_str}'")
                failed += 1
                continue
            
            if exp_minus == "<empty>":
                if a_minus_str != "<empty>" and a_minus_str != "":
                    cocotb.log.warning(f"Test {i+1}: a_minus returned {a_minus_str}, expected <empty>")
            elif a_minus_str != exp_minus:
                cocotb.log.error(f"Test {i+1}: a_minus mismatch. Expected '{exp_minus}', got '{a_minus_str}'")
                failed += 1
                continue
            
            cocotb.log.info(f"Test {i+1}: PASS (a_plus='{a_plus_str}', a_minus='{a_minus_str}')")
        else:
            cocotb.log.info(f"Test {i+1}: PASS (invalid case)")
        
        passed += 1
        
        # Wait a few cycles between tests
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
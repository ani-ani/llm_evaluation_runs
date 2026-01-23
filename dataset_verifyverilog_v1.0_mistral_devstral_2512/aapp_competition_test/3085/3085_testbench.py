import cocotb
from cocotb.triggers import Timer
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
    return min(max_val, max(0, value))

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_bracket_converter(dut):
    """Test the bracket converter module."""
    
    # Test cases: (description, input_string, expected_output_string)
    # Input format: 4-character string padded with zeros if needed
    # ASCII: '(' = 0x28, ')' = 0x29
    # We represent input as 32-bit value where byte0 (LSB) = first char
    test_cases = [
        (
            "()",
            "()",
            "4,4:"
        ),
        (
            "(())",
            "(())",
            "4,8:8,8:"
        ),
        (
            "()()",
            "()()",
            "4,4:8,8:"
        )
    ]
    
    passed = 0
    failed = 0
    
    for i, (desc, in_str, expected_out) in enumerate(test_cases):
        dut._log.info(f"Test {i+1}: {desc}")
        
        try:
            # Convert input string to 32-bit value
            # in_str[0] -> bits 7:0, in_str[1] -> bits 15:8, etc.
            in_val = 0
            for j, char in enumerate(in_str):
                in_val |= (ord(char) << (j * 8))
            
            # Pad with zeros if string is shorter than 4 chars
            for j in range(len(in_str), 4):
                in_val |= (0 << (j * 8))
            
            dut.in_str.value = in_val
            
            # Wait for combinational propagation
            await Timer(10, units='ns')
            
            # Read output
            if not is_value_defined(dut.out_str.value):
                raise TestFailure("Output is undefined (X/Z)")
            
            output_val = int(dut.out_str.value)
            
            # Convert output value to string
            output_str = ""
            for j in range(8):  # Output is 8 characters max
                byte = (output_val >> (j * 8)) & 0xFF
                if byte != 0:
                    output_str += chr(byte)
            
            # Compare
            if output_str != expected_out:
                raise TestFailure(
                    f"Expected '{expected_out}', got '{output_str}'"
                )
            
            cocotb.log.info(f"  PASS: output = {output_str}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
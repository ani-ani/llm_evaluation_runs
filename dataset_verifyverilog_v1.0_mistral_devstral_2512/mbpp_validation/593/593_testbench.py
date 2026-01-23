import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure
import re

# ============================================================================
# CONFIGURATION
# ============================================================================
CHAR_WIDTH = 8
STRING_LEN = 16

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    try:
        return int(value)
    except ValueError:
        return default

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def string_to_ascii_list(s, length=STRING_LEN):
    ascii_vals = [ord(c) for c in s]
    while len(ascii_vals) < length:
        ascii_vals.append(0x20)
    return ascii_vals[:length]

def ascii_list_to_string(ascii_list):
    chars = []
    for val in ascii_list:
        if val == 0x20:
            break
        chars.append(chr(val))
    return ''.join(chars)

# ============================================================================
# REFERENCE IMPLEMENTATION
# ============================================================================

def reference_removezero_ip(ip):
    string = re.sub(r'\.[0]*', '.', ip)
    return string

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_removezero_ip(dut):
    test_cases = [
        ("216.08.094.196", "216.8.94.196"),
        ("12.01.024", "12.1.24"),
        ("216.08.094.0196", "216.8.94.196"),
        ("0.0.0.0", "0.0.0.0"),
        ("192.168.1.1", "192.168.1.1"),
        ("001.02.003.004", "1.2.3.4"),
    ]
    
    for i, (input_str, expected_str) in enumerate(test_cases):
        dut._log.info(f"Test {i+1}: '{input_str}' -> '{expected_str}'")
        
        input_ascii = string_to_ascii_list(input_str)
        expected_ascii = string_to_ascii_list(expected_str)
        
        for j in range(STRING_LEN):
            port_name = f"char_in_{j}"
            if has_signal(dut, port_name):
                getattr(dut, port_name).value = input_ascii[j]
        
        await Timer(50, units='ns')
        
        output_ascii = []
        for j in range(STRING_LEN):
            port_name = f"char_out_{j}"
            if has_signal(dut, port_name):
                val = safe_int(getattr(dut, port_name).value)
                output_ascii.append(val)
            else:
                raise TestFailure(f"Cannot find output port for index {j}")
        
        result_str = ascii_list_to_string(output_ascii)
        result_expected = ascii_list_to_string(expected_ascii)
        
        if result_str != result_expected:
            dut._log.error(f"  Input ASCII:    {input_ascii}")
            dut._log.error(f"  Output ASCII:   {output_ascii}")
            dut._log.error(f"  Expected ASCII: {expected_ascii}")
            dut._log.error(f"  Result string:   '{result_str}'")
            dut._log.error(f"  Expected string: '{result_expected}'")
            raise TestFailure(f"Test {i+1} failed: got '{result_str}', expected '{result_expected}'")
        
        dut._log.info(f"  PASS: '{result_str}'")
    
    dut._log.info(f"All {len(test_cases)} tests passed!")

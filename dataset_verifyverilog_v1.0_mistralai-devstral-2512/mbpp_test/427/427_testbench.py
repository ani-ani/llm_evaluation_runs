import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure
import struct

# Helper to pack 10 ASCII characters into an 80-bit integer
def pack_string(s):
    if len(s) != 10:
        raise ValueError("Input string must be exactly 10 characters")
    val = 0
    for i, char in enumerate(s):
        val |= ord(char) << (8 * i)
    return val

# Helper to unpack 80-bit integer to string
def unpack_string(val):
    chars = []
    for i in range(10):
        byte = (val >> (8 * i)) & 0xFF
        chars.append(chr(byte))
    return ''.join(chars)

@cocotb.test(timeout_time=1, timeout_unit='ms')
async def test_date_conversion(dut):
    # Test cases from the prompt
    test_cases = [
        ("2026-01-02", "02-01-2026"),
        ("2020-11-13", "13-11-2020"),
        ("2021-04-26", "26-04-2021")
    ]
    
    for i, (input_str, expected_str) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {input_str} -> {expected_str}")
        
        # Pack inputs
        packed_input = pack_string(input_str)
        dut.date_in.value = packed_input
        
        # Wait for combinational propagation
        await Timer(10, units='ns')
        
        # Read output
        output_val = int(dut.date_out.value)
        output_str = unpack_string(output_val)
        
        if output_str != expected_str:
            raise TestFailure(f"Test {i+1} failed: Expected '{expected_str}', got '{output_str}'")
        
    cocotb.log.info("All tests passed!")
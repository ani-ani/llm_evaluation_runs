import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure
import random

# Helper function to check if value is defined (not X/Z)
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

# Helper to convert base 10 to base 'base' string
def convert_base_py(x, base):
    if x == 0:
        return "0"
    digits = []
    while x > 0:
        digits.append(str(x % base))
        x //= base
    return "".join(reversed(digits))

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_change_base(dut):
    """Test change_base module with various inputs."""
    
    # Setup Clock
    clock = Clock(dut.clk, 10, units="ns")  # 100 MHz
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.x.value = 0
    dut.base.value = 0
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Define Test Cases
    # (x, base, expected_string)
    test_cases = [
        (8, 3, "22"),
        (9, 3, "100"),
        (234, 2, "11101010"),
        (16, 2, "10000"),
        (8, 2, "1000"),
        (7, 2, "111"),
        (2, 3, "2"),
        (3, 4, "3"),
        (10, 4, "22"),
    ]
    
    passed = 0
    total = len(test_cases)
    
    dut._log.info(f"Starting {total} tests...")
    
    for x_val, base_val, expected_str in test_cases:
        dut._log.info(f"Testing x={x_val}, base={base_val}, expected='{expected_str}'")
        
        # Set inputs
        dut.x.value = x_val
        dut.base.value = base_val
        
        # Pulse start
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done signal with cycle timeout
        # The algorithm might take up to ~20 cycles for small numbers
        max_cycles = 50
        done_found = False
        
        for cycle in range(max_cycles):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and dut.done.value == 1:
                done_found = True
                break
        
        if not done_found:
            raise TestFailure(f"Timeout: Done signal not asserted after {max_cycles} cycles for x={x_val}, base={base_val}")
            
        # Read outputs
        # Check if outputs are defined
        if not is_value_defined(dut.result_str.value) or not is_value_defined(dut.str_len.value):
            raise TestFailure("Output signals are undefined (X/Z)")
            
        result_str_val = int(dut.result_str.value)
        str_len_val = int(dut.str_len.value)
        
        # Decode the 128-bit result_str to string
        # The specification says: bytes 15 down to 0 are characters
        # But usually standard packing is [127:120] is byte 15, [7:0] is byte 0.
        # Let's extract byte by byte from 15 down to 0 to form the string.
        
        decoded_chars = []
        for i in range(15, -1, -1): # Iterate byte indices 15 to 0
            byte_val = (result_str_val >> (i * 8)) & 0xFF
            if byte_val == 0x20: # Space indicates padding/end if we are before len
                # We only care about the first str_len_val characters
                pass
            else:
                decoded_chars.append(chr(byte_val))
        
        # Reconstruct string. The spec says "left-aligned and padded with spaces on the right".
        # So the valid characters come first in the array of bytes.
        # If the result is "22", bytes 15 and 14 are '2', bytes 13-0 are ' '.
        # Let's extract bytes 15 down to 16-str_len.
        
        actual_str = ""
        for i in range(15, 15 - str_len_val, -1):
            byte_val = (result_str_val >> (i * 8)) & 0xFF
            actual_str += chr(byte_val)
            
        # The prompt says: "Least significant byte (result_str[7:0]) corresponds to the last character".
        # This implies the string is stored Little Endian byte order for characters?
        # Let's re-read carefully: "Least significant byte (result_str[7:0]) corresponds to the last character of the string".
        # If string is "22", last char is '2'. LSB is '2'. Next byte is '2'.
        # So result_str = { [15:8]=' ', [7:0]='2' } ? No, that would be " 2".
        # Wait, "Left-aligned and padded with spaces on the right".
        # "22" (len 2) -> bytes 15 and 14 are '2', 13..0 are ' '.
        # Prompt: "Example: '22'. ASCII: '2' = 0x32. result_str[127:120] = 0x32, result_str[119:112] = 0x32".
        # This matches MSB-first storage.
        # But then it says "Least significant byte corresponds to the last character". This is contradictory or I am misreading.
        # If MSB is first char, LSB is last char (if string is placed at top). 
        # Actually, if result_str is treated as a 16-byte array index 0 to 15.
        # Usually index 0 is LSB bits.
        # If index 0 is last character, then string flows from MSB to LSB.
        # So index 15 = char 0, index 0 = char 15.
        # This is standard Big Endian for the string.
        # Let's assume the implementation stores it MSB-first.
        # So for "22", index 15='2', index 14='2'.
        # But what if the test expects something else?
        # Let's look at the "Example: 3.5" in prompt. That's about Q-format.
        # Let's stick to the explicit example: `result_str[127:120] = 0x32, result_str[119:112] = 0x32`.
        # This confirms MSB-first.
        # So I will extract from MSB (index 15) downwards.
        
        actual_str_manual = ""
        for i in range(15, -1, -1):
            # i=15 is bits 127:120
            shift = i * 8
            byte_val = (result_str_val >> shift) & 0xFF
            if byte_val != 0x20: # Skip padding for comparison logic if needed, but we have length
                actual_str_manual += chr(byte_val)
            elif len(actual_str_manual) > 0:
                # Padding encountered inside string? Should not happen if left aligned.
                pass
        
        # Better: Use str_len to determine which bytes to read.
        # If len=2, we need bytes 15 and 14.
        # Bits 127:120 and 119:112.
        
        extracted_str = ""
        for i in range(str_len_val):
            # i=0 corresponds to the first character (MSB)
            # Bit index = 127 - (i*8) down to 120 - (i*8)? No.
            # i=0 -> bits 127:120
            # i=1 -> bits 119:112
            high_bit = 127 - (i * 8)
            low_bit = 120 - (i * 8)
            byte_val = (result_str_val >> low_bit) & 0xFF
            extracted_str += chr(byte_val)
            
        if extracted_str != expected_str:
            raise TestFailure(f"Mismatch for x={x_val}, base={base_val}: Expected '{expected_str}', got '{extracted_str}' (Len: {str_len_val}, Raw: {hex(result_str_val)})")
        
        passed += 1
        dut._log.info(f"Passed: {extracted_str}")
        
        # Small delay between tests
        await Timer(20, units="ns")

    dut._log.info(f"\nSummary: {passed}/{total} tests passed")
    if passed != total:
        raise TestFailure(f"Only {passed}/{total} tests passed")

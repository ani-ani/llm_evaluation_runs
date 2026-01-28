import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure, TestSuccess
import random

# Helper function to check if value is defined (not X/Z)
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

# Helper to pack a list of 16 bytes into a 128-bit integer
def pack_bytes(byte_list):
    val = 0
    for i, b in enumerate(byte_list):
        val |= (b << (8 * i))
    return val

# Helper to unpack 128-bit integer into list of 16 bytes
def unpack_bytes(val):
    return [(val >> (8 * i)) & 0xFF for i in range(16)]

# Helper: Check if byte is letter
def is_letter(b):
    return (ord('A') <= b <= ord('Z')) or (ord('a') <= b <= ord('z'))

# Helper: Flip case
def flip_case(b):
    if is_letter(b):
        return b ^ 0x20
    return b

@cocotb.test(timeout_time=2, timeout_unit='ms')
async def test_string_transform(dut):
    """Test the string_transform module"""
    
    # Setup Clock
    clock = Clock(dut.clk, 10, units="ns")  # 100MHz
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.data_in.value = 0
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Define test cases
    test_cases = [
        # Case 1: Has letters (should flip case)
        {
            "input_str": "AsDf123456789012",
            "description": "Mixed letters and numbers"
        },
        # Case 2: No letters (should reverse)
        {
            "input_str": "1234567890123456",
            "description": "Only numbers"
        },
        # Case 3: Mixed symbols and letters
        {
            "input_str": "#a@C\\n\\n\\n\\n\\n\\n\\n",
            "description": "Symbols and letters"
        },
        # Case 4: All lowercase
        {
            "input_str": "abcdef0123456789",
            "description": "All lowercase letters"
        },
        # Case 5: Empty (padded) - actually check whitespace (non-letter)
        {
            "input_str": "     ",
            "description": "Spaces (non-letters)"
        },
        # Case 6: Specific test from prompt
        {
            "input_str": "#AsdfW^45\0\0\0\0\0\0",
            "description": "Prompt example padded"
        }
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, tc in enumerate(test_cases):
        # Prepare Input
        s = tc["input_str"]
        # Ensure length is 16, pad with nulls if shorter
        s_bytes = s.encode('ascii')[:16]
        s_bytes = s_bytes + bytes([0] * (16 - len(s_bytes)))
        
        # Pack into integer
        packed_input = pack_bytes(s_bytes)
        
        # Calculate Expected Output
        # 1. Check for letters
        has_letter = any(is_letter(b) for b in s_bytes)
        
        expected_bytes = [0]*16
        if has_letter:
            # Flip case
            expected_bytes = [flip_case(b) for b in s_bytes]
        else:
            # Reverse
            expected_bytes = list(reversed(s_bytes))
        
        packed_expected = pack_bytes(expected_bytes)
        
        # Drive DUT
        dut.data_in.value = packed_input
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done with timeout
        max_cycles = 40
        done_found = False
        for _ in range(max_cycles):
            if not is_value_defined(dut.done.value):
                await RisingEdge(dut.clk)
                continue
            if dut.done.value == 1:
                done_found = True
                break
            await RisingEdge(dut.clk)
        
        if not done_found:
            raise TestFailure(f"Test {i} ({tc['description']}): Timeout waiting for done signal")
        
        # Read Output
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Test {i} ({tc['description']}): Result is undefined (X/Z)")
            
        actual = int(dut.result.value)
        
        # Compare
        if actual != packed_expected:
            # Decode for debugging
            actual_str = "".join([chr(b) if 32 <= b < 127 else '.' for b in unpack_bytes(actual)])
            expected_str = "".join([chr(b) if 32 <= b < 127 else '.' for b in unpack_bytes(packed_expected)])
            raise TestFailure(f"Test {i} ({tc['description']}) failed.\nInput: {s}\nExpected: {expected_str} (0x{packed_expected:x})\nGot: {actual_str} (0x{actual:x})")
        else:
            dut._log.info(f"Test {i} ({tc['description']}) passed")
            passed += 1
            
        await RisingEdge(dut.clk)
        
    dut._log.info(f"\nSUMMARY: {passed}/{total} tests passed")
    if passed == total:
        raise TestSuccess("All tests passed")
    else:
        raise TestFailure(f"{total - passed} tests failed")
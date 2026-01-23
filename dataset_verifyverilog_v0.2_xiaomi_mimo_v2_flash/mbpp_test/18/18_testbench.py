import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
import random

def str_to_bytes(s, max_len=16):
    """Convert string to list of bytes padded to max_len"""
    bytes_list = [ord(c) for c in s]
    while len(bytes_list) < max_len:
        bytes_list.append(0)
    return bytes_list

def bytes_to_hex(bytes_list):
    """Convert byte list to hex string for display"""
    return ' '.join(f'{b:02x}' for b in bytes_list)

def pack_bytes(bytes_list):
    """Pack 16 bytes into 128-bit integer (little-endian: byte0 at LSB)"""
    result = 0
    for i, b in enumerate(bytes_list):
        result |= (b << (8 * i))
    return result

def unpack_bytes(value):
    """Unpack 128-bit integer into 16 bytes (little-endian)"""
    bytes_list = []
    for i in range(16):
        bytes_list.append((value >> (8 * i)) & 0xFF)
    return bytes_list

def filter_string(s, f):
    """Python reference implementation"""
    filter_set = set(f)
    result = [c for c in s if c not in filter_set]
    return ''.join(result)

@cocotb.test()
async def test_string_filter(dut):
    """Test string filtering functionality"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.str_in.value = 0
    dut.filter_str.value = 0
    dut.str_len.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        ("probasscurve", "pros", "bacuve"),
        ("digitalindia", "talent", "digiidi"),
        ("exoticmiles", "toxic", "emles"),
        ("aabbcc", "abc", ""),  # All removed
        ("xyz", "abc", "xyz"),   # None removed
        ("aaaaa", "a", ""),      # Single char all removed
        ("test123", "0123", "test"), # Digits removed
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, (input_str, filter_str, expected_str) in enumerate(test_cases):
        print(f"
Test {i+1}: '{input_str}' - '{filter_str}' -> '{expected_str}'")
        
        # Pack inputs
        input_bytes = str_to_bytes(input_str)
        filter_bytes = str_to_bytes(filter_str)
        
        dut.str_in.value = pack_bytes(input_bytes)
        dut.filter_str.value = pack_bytes(filter_bytes)
        dut.str_len.value = len(input_str)
        
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done (max 20 cycles to be safe)
        timeout = 0
        while not dut.done.value and timeout < 20:
            await RisingEdge(dut.clk)
            timeout += 1
        
        if timeout >= 20:
            print(f"  FAILED: Timeout waiting for done")
            continue
        
        # Read result
        result_packed = int(dut.result.value)
        result_len = int(dut.result_len.value)
        result_bytes = unpack_bytes(result_packed)
        
        # Extract only valid characters
        actual_result = ''.join(chr(b) for b in result_bytes[:result_len])
        
        # Verify
        if actual_result == expected_str and result_len == len(expected_str):
            print(f"  PASSED: Got '{actual_result}' (len={result_len})")
            passed += 1
        else:
            print(f"  FAILED: Expected '{expected_str}' (len={len(expected_str)}), got '{actual_result}' (len={result_len})")
            print(f"  Result bytes: {bytes_to_hex(result_bytes[:result_len])}")
    
    print(f"
{passed}/{total} tests passed")
    assert passed == total, f"Only {passed}/{total} tests passed"

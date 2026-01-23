import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure
import random

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

async def wait_for_done(dut, max_cycles=20):
    """Wait for done signal to go high."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and dut.done.value == 1:
            return cycle
    raise TestFailure(f"Timeout: done never went high after {max_cycles} cycles")

def string_to_bytes(s):
    """Convert string to list of byte values."""
    return [ord(c) for c in s]

def pack_bytes(byte_list, max_len=8):
    """Pack bytes into integer for assignment."""
    result = 0
    for i in range(min(len(byte_list), max_len)):
        result |= (byte_list[i] << (i * 8))
    return result

def check_prefix_output(prefix_array, length):
    """Extract prefix bytes from array."""
    prefix = []
    for i in range(length):
        val = int(prefix_array[i].value)
        prefix.append(chr(val))
    return ''.join(prefix)

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_all_prefixes(dut):
    """Test all_prefixes module with various strings."""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.len.value = 0
    for i in range(8):
        dut.str[i].value = 0
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        ("", []),
        ("W", ["W"]),
        ("WW", ["W", "WW"]),
        ("WWW", ["W", "WW", "WWW"]),
        ("a", ["a"]),
        ("abc", ["a", "ab", "abc"]),
        ("asdfgh", ["a", "as", "asd", "asdf", "asdfg", "asdfgh"]),
    ]
    
    total_tests = len(test_cases)
    passed_tests = 0
    
    for test_str, expected_prefixes in test_cases:
        dut._log.info(f"Testing string: '{test_str}' (length {len(test_str)})")
        
        # Convert string to bytes
        str_bytes = string_to_bytes(test_str)
        
        # Load input
        for i in range(8):
            if i < len(str_bytes):
                dut.str[i].value = str_bytes[i]
            else:
                dut.str[i].value = 0
        dut.len.value = len(test_str)
        
        # Start computation
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Collect outputs
        collected_prefixes = []
        
        for prefix_idx, expected_prefix in enumerate(expected_prefixes):
            # Wait for valid to go high
            timeout_count = 0
            while timeout_count < 100:
                await RisingEdge(dut.clk)
                timeout_count += 1
                if is_value_defined(dut.valid.value) and dut.valid.value == 1:
                    break
                if is_value_defined(dut.done.value) and dut.done.value == 1:
                    break
            else:
                raise TestFailure(f"Timeout waiting for valid/prefix {prefix_idx}")
            
            # Check if valid is high
            if not is_value_defined(dut.valid.value) or dut.valid.value != 1:
                # Might be done instead
                if is_value_defined(dut.done.value) and dut.done.value == 1:
                    break
                raise TestFailure(f"Valid not high for prefix {prefix_idx}")
            
            # Read prefix
            if not is_value_defined(dut.prefix_len.value):
                raise TestFailure(f"Prefix length undefined at prefix {prefix_idx}")
            
            actual_len = int(dut.prefix_len.value)
            actual_prefix = check_prefix_output(dut.prefix, actual_len)
            collected_prefixes.append(actual_prefix)
            
            if actual_prefix != expected_prefix:
                raise TestFailure(f"Prefix {prefix_idx}: expected '{expected_prefix}', got '{actual_prefix}'")
            
            dut._log.info(f"  Prefix {prefix_idx}: '{actual_prefix}' [OK]")
        
        # Wait for done
        await RisingEdge(dut.clk)
        if not (is_value_defined(dut.done.value) and dut.done.value == 1):
            # Wait one more cycle if needed
            await RisingEdge(dut.clk)
        
        if not (is_value_defined(dut.done.value) and dut.done.value == 1):
            # Not necessarily an error if no prefixes expected
            if len(expected_prefixes) > 0:
                raise TestFailure("Done signal not high after processing")
        
        # Verify collected matches expected
        if collected_prefixes == expected_prefixes:
            passed_tests += 1
            dut._log.info(f"Test case '{test_str}' PASSED")
        else:
            dut._log.error(f"Test case '{test_str}' FAILED")
            dut._log.error(f"  Expected: {expected_prefixes}")
            dut._log.error(f"  Got: {collected_prefixes}")
    
    dut._log.info(f"\n=== SUMMARY: {passed_tests}/{total_tests} tests passed ===")
    if passed_tests != total_tests:
        raise TestFailure(f"Only {passed_tests}/{total_tests} tests passed")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_edge_cases(dut):
    """Test edge cases: empty string, single char, max length."""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.len.value = 0
    for i in range(8):
        dut.str[i].value = 0
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test empty string
    dut._log.info("Test: Empty string")
    for i in range(8):
        dut.str[i].value = 0
    dut.len.value = 0
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Should go to done without any valid pulses
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    
    if is_value_defined(dut.done.value) and dut.done.value == 1:
        dut._log.info("Empty string test PASSED")
    else:
        raise TestFailure("Empty string: done should be high after 2 cycles")
    
    # Test maximum length string
    dut._log.info("Test: Maximum length (8 chars)")
    max_str = "ABCDEFGH"
    str_bytes = string_to_bytes(max_str)
    for i in range(8):
        dut.str[i].value = str_bytes[i]
    dut.len.value = 8
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Collect all 8 prefixes
    prefixes = []
    for i in range(8):
        # Wait for valid
        for _ in range(10):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.valid.value) and dut.valid.value == 1:
                break
        else:
            raise TestFailure(f"Timeout at prefix {i}")
        
        length = int(dut.prefix_len.value)
        prefix = check_prefix_output(dut.prefix, length)
        prefixes.append(prefix)
        dut._log.info(f"  Prefix {i}: '{prefix}'")
    
    expected = ["A", "AB", "ABC", "ABCD", "ABCDE", "ABCDEF", "ABCDEFG", "ABCDEFGH"]
    if prefixes == expected:
        dut._log.info("Max length test PASSED")
    else:
        raise TestFailure(f"Max length: expected {expected}, got {prefixes}")
    
    dut._log.info("All edge case tests completed")

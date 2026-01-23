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

def ascii_to_hex(c):
    """Convert character to its ASCII hex value."""
    return ord(c)

def pack_string(s, max_len=8):
    """Pack a Python string into a list of ASCII values for Verilog array access."""
    result = []
    for i in range(max_len):
        if i < len(s):
            result.append(ascii_to_hex(s[i]))
        else:
            result.append(0)
    return result

def remove_vowels_py(s):
    """Python reference implementation."""
    vowels = set('aeiou')
    return ''.join(c for c in s if c not in vowels)

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_remove_vowels(dut):
    """Test remove_vowels module with various strings."""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    for i in range(8):
        dut.str[i].value = 0
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (input_string, expected_output_string)
    test_cases = [
        ("", ""),
        ("abcdef\nghijklm", "bcdf\nghjklm"[:8]),  # Truncate to 8 chars
        ("abcdef", "bcdf"),
        ("aaaaa", ""),
        ("aaBAA", "B"),
        ("zbcd", "zbcd"),
        ("EcBOO", "cB"),
        ("fedcba", "fdcb"),
    ]
    
    total_tests = len(test_cases)
    passed_tests = 0
    
    dut._log.info(f"Starting {total_tests} tests...")
    
    for i, (input_str, expected_str) in enumerate(test_cases):
        dut._log.info(f"\nTest {i+1}: Input='{input_str}' (len={len(input_str)})")
        
        # Pack input string into array
        input_array = pack_string(input_str, 8)
        for j in range(8):
            dut.str[j].value = input_array[j]
        
        # Wait for next clock edge then pulse start
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done signal with timeout
        max_cycles = 20
        done_received = False
        
        for cycle in range(max_cycles):
            await RisingEdge(dut.clk)
            
            if not is_value_defined(dut.done.value):
                continue
            
            if dut.done.value == 1:
                done_received = True
                break
        
        if not done_received:
            raise TestFailure(f"Test {i+1}: Done signal not received after {max_cycles} cycles")
        
        # Verify output is defined
        if not is_value_defined(dut.result_len.value):
            raise TestFailure(f"Test {i+1}: result_len is undefined (X/Z)")
        
        # Read result length
        result_len = int(dut.result_len.value)
        
        # Read output string
        output_chars = []
        for j in range(8):
            if not is_value_defined(dut.result[j].value):
                raise TestFailure(f"Test {i+1}: result[{j}] is undefined")
            output_chars.append(chr(int(dut.result[j].value)))
        
        # Construct output string (first result_len characters, skip nulls)
        output_str = ''.join(output_chars[:result_len])
        
        # Remove nulls from output_str (shouldn't be any except padding)
        output_str = output_str.replace('\x00', '')
        
        # Verify
        dut._log.info(f"  Output: '{output_str}' (len={result_len}, raw={output_chars})")
        dut._log.info(f"  Expected: '{expected_str}' (len={len(expected_str)})")
        
        if output_str != expected_str:
            raise TestFailure(f"Test {i+1}: Expected '{expected_str}', got '{output_str}'")
        
        if result_len != len(expected_str):
            raise TestFailure(f"Test {i+1}: Length mismatch - expected {len(expected_str)}, got {result_len}")
        
        passed_tests += 1
        dut._log.info(f"Test {i+1} [PASSED]")
    
    dut._log.info(f"\n{'='*50}")
    dut._log.info(f"SUMMARY: {passed_tests}/{total_tests} tests passed")
    dut._log.info(f"{'='*50}")
    
    if passed_tests != total_tests:
        raise TestFailure(f"Not all tests passed: {passed_tests}/{total_tests}")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_edge_cases(dut):
    """Test edge cases for remove_vowels."""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    for i in range(8):
        dut.str[i].value = 0
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test: All vowels
    dut._log.info("Edge case: All vowels 'aeiouae'")
    input_str = "aeiouae"
    input_array = pack_string(input_str, 8)
    for j in range(8):
        dut.str[j].value = input_array[j]
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    for _ in range(15):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and dut.done.value == 1:
            break
    
    result_len = int(dut.result_len.value)
    if result_len != 0:
        raise TestFailure(f"All vowels test: expected length 0, got {result_len}")
    dut._log.info("All vowels test [PASSED]")
    
    # Test: All consonants
    dut._log.info("Edge case: All consonants 'zbcdqwr'")
    input_str = "zbcdqwr"
    input_array = pack_string(input_str, 8)
    for j in range(8):
        dut.str[j].value = input_array[j]
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(15):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and dut.done.value == 1:
            break
    
    result_len = int(dut.result_len.value)
    output_chars = [chr(int(dut.result[j].value)) for j in range(result_len)]
    output_str = ''.join(output_chars)
    expected = "zbcdqwr"
    
    if output_str != expected:
        raise TestFailure(f"All consonants: expected '{expected}', got '{output_str}'")
    dut._log.info("All consonants test [PASSED]")
    
    # Test: Mixed with newlines
    dut._log.info("Edge case: Newline preservation 'a\nb\nc'")
    input_str = "a\nb\nc"
    input_array = pack_string(input_str, 8)
    for j in range(8):
        dut.str[j].value = input_array[j]
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(15):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and dut.done.value == 1:
            break
    
    result_len = int(dut.result_len.value)
    output_chars = [chr(int(dut.result[j].value)) for j in range(result_len)]
    output_str = ''.join(output_chars)
    expected = "\nb\nc"
    
    if output_str != expected:
        raise TestFailure(f"Newline test: expected '{expected}', got '{output_str}'")
    dut._log.info("Newline test [PASSED]")
    
    dut._log.info("All edge case tests passed!")

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure
import random

# Helper to convert string to bytes
def str_to_bytes(s, width=8):
    b = s.encode('ascii')
    if len(b) > width:
        raise ValueError(f"String {s} too long for width {width}")
    # Pad with zeros
    return b.ljust(width, b'\x00')

# Helper to check defined value
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_longest_string(dut):
    """Test longest string finder with fixed-width strings."""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.count.value = 0
    
    # Initialize array inputs to 0
    for i in range(4):
        for j in range(8):
            dut.strings[i][j].value = 0
    
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        # (list_of_strings, expected_index)
        ([], 0),  # Empty list: index 0 is returned (mapped to None behavior)
        (["a"], 0),
        (["a", "b", "c"], 0),  # All length 1, first is returned
        (["a", "bb", "ccc"], 2),
        (["x", "yyy", "zzzz", "www"], 2),
        (["abc", "defgh", "xy", "ijklmno"], 3),  # 'ijklmno' is 7 chars, longest
        (["abcdefgh", "short", "ab", "medium"], 0),  # 'abcdefgh' is 8 chars
        (["aaaa", "bbbb", "cccc", "dddd"], 0),  # All length 4, first
    ]
    
    for i, (strings, expected_idx) in enumerate(test_cases):
        dut._log.info(f"Running test case {i}: {strings}")
        
        # Set inputs
        dut.start.value = 1
        dut.count.value = len(strings)
        
        # Fill array
        for s_idx in range(4):
            if s_idx < len(strings):
                # Convert string to bytes
                b = str_to_bytes(strings[s_idx], 8)
                for c_idx in range(8):
                    dut.strings[s_idx][c_idx].value = b[c_idx]
            else:
                # Clear unused entries
                for c_idx in range(8):
                    dut.strings[s_idx][c_idx].value = 0
        
        # Wait for start to be sampled
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for valid signal with timeout
        # Expected latency: 20 cycles
        found = False
        for _ in range(50):  # Wait up to 50 cycles
            await RisingEdge(dut.clk)
            if is_value_defined(dut.valid.value) and dut.valid.value == 1:
                found = True
                break
        
        if not found:
            raise TestFailure(f"Test {i}: valid signal did not go high")
        
        if not is_value_defined(dut.index.value):
            raise TestFailure(f"Test {i}: index output is undefined (X/Z)")
            
        result_idx = int(dut.index.value)
        
        if result_idx != expected_idx:
            raise TestFailure(f"Test {i}: Expected index {expected_idx}, got {result_idx}")
        
        dut._log.info(f"Test {i} passed: {strings} -> index {result_idx}")
        
        # Small delay between tests
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
    
    dut._log.info(f"All {len(test_cases)} tests passed")

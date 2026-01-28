import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration
DATA_WIDTH = 8
STRING_LENGTH = 16
RESULT_WIDTH = 5
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

# Helper functions
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

async def reset_dut(dut):
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def start_computation(dut):
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

async def write_string(dut, s, length):
    """Write string characters to individual ports"""
    # Write characters
    for i in range(16):
        port_name = f"char{i}"
        if has_signal(dut, port_name):
            if i < length:
                getattr(dut, port_name).value = ord(s[i])
            else:
                getattr(dut, port_name).value = 0
        else:
            raise TestFailure(f"Signal {port_name} not found")
    
    # Set length
    dut.length_in.value = length

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_longest_repeated_substring(dut):
    """Test longest repeated substring module"""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (string, length, expected_result, description)
    test_cases = [
        ("sabcabcfabc", 11, 3, "Example 1: 'abc' repeats"),
        ("trutrutiktikta", 16, 4, "Example 2: 'trut' or 'tikt' repeats"),
        ("abcdef", 6, 0, "Example 3: No repeats"),
        ("aaaa", 4, 3, "All same: 'aaa' repeats"),
        ("abab", 4, 2, "Alternating: 'ab' repeats"),
        ("", 0, 0, "Empty string")
    ]
    
    passed = 0
    failed = 0
    
    for i, (test_string, length, expected, description) in enumerate(test_cases):
        dut._log.info(f"Test {i+1}: {description}")
        
        try:
            # Write inputs
            await write_string(dut, test_string, length)
            
            # Start computation
            await start_computation(dut)
            
            # Wait for completion
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result = int(dut.result.value)
            
            # Verify
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            dut._log.info(f"  PASS: result = {result}")
            passed += 1
            
        except TestFailure as e:
            dut._log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    dut._log.info(f"{'='*50}")
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration
DATA_WIDTH = 8
MAX_STRING_LEN = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 500

# Helper functions
def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

def clamp_to_width(value, bits):
    """Clamp value to fit within specified bit width (unsigned)."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

def has_signal(dut, name):
    """Check if DUT has a signal with given name."""
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def string_to_bytes(s, max_len):
    """Convert string to list of byte values (ASCII), pad to max_len."""
    bytes_list = [ord(c) for c in s[:max_len]]
    # Pad with zeros
    while len(bytes_list) < max_len:
        bytes_list.append(0)
    return bytes_list

async def reset_dut(dut):
    """Reset the DUT."""
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    """Wait for done signal with timeout."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def start_computation(dut):
    """Pulse start signal."""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_lps(dut):
    """Test LPS module with example strings."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (string, expected_lps_length)
    # Note: We truncate/pad strings to 8 characters
    test_cases = [
        ("TENS FOR", 5),        # Truncated from "TENS FOR TENS"
        ("CARDS FOR", 7),       # Truncated from "CARDIO FOR CARDS"
        ("PART JOURN", 9),      # Truncated from "PART OF THE JOURNEY IS PART"
        ("ABA", 3),             # Simple palindrome
        ("ABC", 1),             # No palindrome
        ("AAAA", 4),            # All same
        ("", 0),                # Empty
    ]
    
    passed = 0
    failed = 0
    
    for test_num, (test_str, expected) in enumerate(test_cases):
        # Truncate to 8 chars
        truncated = test_str[:MAX_STRING_LEN]
        actual_len = len(truncated)
        
        # Convert to byte list
        byte_values = string_to_bytes(truncated, MAX_STRING_LEN)
        
        cocotb.log.info(f"Test {test_num+1}: String='{truncated}' (len={actual_len}), Expected LPS={expected}")
        
        try:
            # Write input characters to individual ports
            for i in range(MAX_STRING_LEN):
                port_name = f"str_{i}"
                if has_signal(dut, port_name):
                    getattr(dut, port_name).value = byte_values[i]
                else:
                    raise TestFailure(f"Missing signal: {port_name}")
            
            # Write length
            dut.str_len.value = actual_len
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result = int(dut.result.value)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: LPS length = {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")

@cocotb.test(timeout_time=500, timeout_unit="ms")
async def test_edge_cases(dut):
    """Test edge cases."""
    
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test 1: Single character
    cocotb.log.info("Test: Single character 'A'")
    for i in range(MAX_STRING_LEN):
        getattr(dut, f"str_{i}").value = ord('A') if i == 0 else 0
    dut.str_len.value = 1
    await start_computation(dut)
    await wait_for_done(dut)
    result = int(dut.result.value)
    if result != 1:
        raise TestFailure(f"Single char test failed: expected 1, got {result}")
    
    # Test 2: Two different characters
    cocotb.log.info("Test: Two different 'AB'")
    getattr(dut, "str_0").value = ord('A')
    getattr(dut, "str_1").value = ord('B')
    dut.str_len.value = 2
    await start_computation(dut)
    await wait_for_done(dut)
    result = int(dut.result.value)
    if result != 1:
        raise TestFailure(f"Two different test failed: expected 1, got {result}")
    
    # Test 3: Two same characters
    cocotb.log.info("Test: Two same 'AA'")
    getattr(dut, "str_0").value = ord('A')
    getattr(dut, "str_1").value = ord('A')
    dut.str_len.value = 2
    await start_computation(dut)
    await wait_for_done(dut)
    result = int(dut.result.value)
    if result != 2:
        raise TestFailure(f"Two same test failed: expected 2, got {result}")
    
    # Test 4: Length 0
    cocotb.log.info("Test: Empty string")
    dut.str_len.value = 0
    await start_computation(dut)
    await wait_for_done(dut)
    result = int(dut.result.value)
    if result != 0:
        raise TestFailure(f"Empty test failed: expected 0, got {result}")
    
    cocotb.log.info("Edge case tests passed")

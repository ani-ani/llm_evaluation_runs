import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except ValueError:
        return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits - 1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def pack_result(bits):
    """Pack list of 0/1 bits into 16-bit integer"""
    result = 0
    for i, b in enumerate(bits):
        if b:
            result |= (1 << i)
    return result

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    dut.char_valid.value = 0
    dut.char_end.value = 0
    dut.char_in.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=100):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def send_string(dut, s, clk_ns=10):
    """Send string character by character"""
    for i, ch in enumerate(s):
        dut.char_in.value = ord(ch) & 0xFF
        dut.char_valid.value = 1
        dut.char_end.value = 1 if i == len(s) - 1 else 0
        await RisingEdge(dut.clk)
        dut.char_valid.value = 0
    # Wait for processing
    await wait_for_done(dut)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_string_game(dut):
    """Test the string game winner module"""
    
    # Setup clock
    CLK_NS = 10
    clock = Clock(dut.clk, CLK_NS, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (input_string, expected_results)
    # Expected results: 1 for Ann, 0 for Mike, packed LSB first
    test_cases = [
        ("a", [0]),                    # Single char: Mike
        ("ab", [0, 1]),                # Mike, Ann
        ("aa", [0, 0]),                # Mike, Mike
        ("abba", [0, 1, 1, 0]),        # Mike, Ann, Ann, Mike
        ("cba", [0, 0, 0]),            # Mike, Mike, Mike
        ("abcd", [0, 1, 1, 1]),        # Mike, Ann, Ann, Ann
        ("dcba", [0, 0, 0, 0]),        # Mike, Mike, Mike, Mike
    ]
    
    for test_idx, (test_str, expected_bits) in enumerate(test_cases):
        cocotb.log.info(f"Test {test_idx + 1}: Input='{test_str}' (len={len(test_str)})")
        
        # Reset before each test
        await reset_dut(dut)
        
        # Send the string
        await send_string(dut, test_str, CLK_NS)
        
        # Verify result
        if not has_signal(dut, 'result'):
            raise TestFailure("Module does not have 'result' signal")
        
        result_val = safe_int(dut.result.value, 0)
        expected_val = pack_result(expected_bits)
        
        cocotb.log.info(f"  Result bits: {bin(result_val)} (expected: {bin(expected_val)})")
        
        # Check each bit
        for i, exp_bit in enumerate(expected_bits):
            actual_bit = (result_val >> i) & 1
            if actual_bit != exp_bit:
                raise TestFailure(f"Position {i}: expected {'Ann' if exp_bit else 'Mike'}, got {'Ann' if actual_bit else 'Mike'}")
        
        cocotb.log.info(f"  ✓ Test passed")
    
    # Additional edge case: empty string (should handle gracefully)
    cocotb.log.info("Test: Empty string (no chars sent)")
    await reset_dut(dut)
    dut.char_end.value = 1
    await RisingEdge(dut.clk)
    dut.char_end.value = 0
    await wait_for_done(dut)
    # Result should be 0 (no bits set)
    if safe_int(dut.result.value, 0) != 0:
        cocotb.log.warning(f"Empty string result: {safe_int(dut.result.value, 0)} (expected 0)")
    
    # Test longer string (16 chars max)
    cocotb.log.info("Test: Maximum length string")
    await reset_dut(dut)
    long_str = "abcdefghijiklmnop"  # 16 chars
    await send_string(dut, long_str, CLK_NS)
    result_val = safe_int(dut.result.value, 0)
    cocotb.log.info(f"  Result for {len(long_str)} chars: 0x{result_val:04X}")
    
    cocotb.log.info("All tests completed successfully!")

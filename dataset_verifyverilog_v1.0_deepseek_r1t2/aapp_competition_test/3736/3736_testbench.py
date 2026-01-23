import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# MANDATORY HELPER FUNCTIONS
# ============================================================================

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

def pack_string(s, max_len=16):
    """Pack a string into 128-bit value (16 chars, LSB = first char)"""
    s = s[:max_len].ljust(max_len, '\x00')  # Pad with nulls
    packed = 0
    for i, char in enumerate(s):
        packed |= ord(char) << (i*8)
    return packed

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=100):
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def start_computation(dut):
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# TESTBENCH
# ============================================================================

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_mirror_checker(dut):
    """Test mirror checker module"""
    
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (input_string, expected_result, description)
    test_cases = [
        ("AHA", 1, "Simple palindrome"),
        ("Z", 0, "Non-mirror letter"),
        ("XO", 0, "Not palindrome"),
        ("AAA", 1, "All A's"),
        ("AHHA", 1, "Double H"),
        ("BAB", 0, "B not allowed"),
        ("OMMMAAMMMO", 1, "Long valid"),
        ("YYHUIUGYI", 0, "Invalid letter (G)"),
        ("TT", 1, "T palindrome"),
        ("UUU", 1, "U palindrome"),
        ("WYYW", 1, "W and Y"),
        ("MITIM", 1, "M I T"),
        ("VO", 0, "Not palindrome"),
        ("WWS", 0, "Invalid S"),
        ("A", 1, "Single A"),
        ("H", 1, "Single H"),
        ("B", 0, "Single B"),
        ("AAAKTAAA", 1, "Odd length valid"),
        ("AAJAA", 0, "J not allowed"),
        ("ZZ", 0, "Z not allowed"),
        ("SSS", 0, "S not allowed"),
    ]
    
    passed = 0
    failed = 0
    
    for input_str, expected, description in test_cases:
        dut._log.info(f"Test: {description} - '{input_str}'")
        
        # Pack string
        packed = pack_string(input_str)
        dut.string_in.value = packed
        dut.len.value = len(input_str)
        
        try:
            # Start computation
            await start_computation(dut)
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined (X/Z)")
            
            actual = int(dut.result.value)
            if actual != expected:
                raise TestFailure(f"Expected {expected}, got {actual}")
            
            dut._log.info(f"  PASS: result={actual}")
            passed += 1
            
        except TestFailure as e:
            dut._log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    dut._log.info(f"\n{'='*50}")
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")

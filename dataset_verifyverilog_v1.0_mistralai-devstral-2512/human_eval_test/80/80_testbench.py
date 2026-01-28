import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helpers from Section A
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def wait_for_done(dut, max_cycles=100):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def process_string(dut, s):
    """Process a string character by character"""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Send each character
    for char in s:
        dut.char_in.value = ord(char)
        dut.char_valid.value = 1
        await RisingEdge(dut.clk)
        dut.char_valid.value = 0
        await RisingEdge(dut.clk)  # Brief delay between chars
    
    # Signal end of string
    dut.char_done.value = 1
    await RisingEdge(dut.clk)
    dut.char_done.value = 0
    
    # Wait for done
    await wait_for_done(dut)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_is_happy(dut):
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (string, expected_happy)
    test_cases = [
        ("a", False),
        ("aa", False),
        ("abcd", True),
        ("aabb", False),
        ("adb", True),
        ("xyy", False),
        ("iopaxpoi", True),
        ("iopaxioi", False),
        ("abc", True),  # Minimum happy length
        ("abcde", True),  # Longer happy
        ("aaa", False),  # All same
        ("aba", True),   # Alternating
        ("", False),     # Empty string
    ]
    
    passed = 0
    failed = 0
    
    for i, (test_str, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: '{test_str}' (expected: {'happy' if expected else 'not happy'})")
        
        try:
            # Process the string
            await process_string(dut, test_str)
            
            # Read result
            if not is_value_defined(dut.happy.value):
                raise TestFailure("Happy signal undefined")
            
            result = int(dut.happy.value) == 1
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            
            # Small delay between tests
            await Timer(50, units='ns')
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: Test '{test_str}' - {e}")
            failed += 1
            # Reset for next test
            await reset_dut(dut)
    
    # Final summary
    cocotb.log.info(f"\nTest Summary: {passed}/{len(test_cases)} passed")
    if failed:
        raise TestFailure(f"{failed} tests failed out of {len(test_cases)}")
import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def pack_string(s, max_len=16):
    """Pack string into 128-bit integer (8 bits per char)"""
    packed = 0
    for i, ch in enumerate(s[:max_len]):
        packed |= (ord(ch) & 0xFF) << (8 * i)
    return packed

def lps_reference(s):
    """Reference LPS implementation in Python"""
    n = len(s)
    if n == 0:
        return 0
    L = [[0 for x in range(n)] for x in range(n)]
    for i in range(n):
        L[i][i] = 1
    for cl in range(2, n + 1):
        for i in range(n - cl + 1):
            j = i + cl - 1
            if s[i] == s[j] and cl == 2:
                L[i][j] = 2
            elif s[i] == s[j]:
                L[i][j] = L[i + 1][j - 1] + 2
            else:
                L[i][j] = max(L[i][j - 1], L[i + 1][j])
    return L[0][n - 1]

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_lps(dut):
    # Setup clock and reset
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    
    for _ in range(2):
        await RisingEdge(dut.clk)
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases from problem
    test_cases = [
        ("TENS FOR TENS", 5),
        ("CARDIO FOR CARDS", 7),
        ("PART OF THE JOURNEY IS PART", 9),
        ("A", 1),  # Edge case
        ("AB", 1),  # No palindrome
        ("AA", 2),  # Two chars
    ]
    
    passed = 0
    failed = 0
    
    for idx, (test_str, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {idx + 1}: '{test_str}' expecting {expected}")
        
        try:
            # Pack string into 128-bit value
            packed = pack_string(test_str)
            dut.str.value = packed
            dut.len.value = len(test_str)
            
            # Start computation
            if has_signal(dut, 'start'):
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
            
            # Wait for done
            max_cycles = 256
            found_done = False
            for cycle in range(max_cycles):
                await RisingEdge(dut.clk)
                if has_signal(dut, 'done') and is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                    found_done = True
                    break
            
            if not found_done:
                raise TestFailure(f"Timeout: done signal never asserted after {max_cycles} cycles")
            
            # Read result
            if not has_signal(dut, 'result'):
                raise TestFailure("Result signal not found")
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            result = int(dut.result.value)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            cocotb.log.info(f"  PASS: Result = {result}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: Test {idx + 1} - {e}")
            failed += 1
        
        # Small delay between tests
        await Timer(100, units='ns')
    
    if failed:
        raise TestFailure(f"{failed} out of {len(test_cases)} tests failed")
    
    cocotb.log.info(f"All {passed} tests passed!")
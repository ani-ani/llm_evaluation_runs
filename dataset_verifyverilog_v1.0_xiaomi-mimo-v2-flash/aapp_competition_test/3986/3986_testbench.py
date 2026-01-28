import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helper functions from template
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

# Constants for testbench
DATA_WIDTH = 8
MAX_N = 1000
MAX_K = 16
CLK_NS = 10
MAX_CYCLES = 300

def get_expected_string(n, k):
    """Compute expected result (Python)"""
    if k > MAX_K or k > n or (k == 1 and n > 1):
        return None  # Error
    if n == 1 and k == 1:
        return 'a'
    
    # Generate first part: n - k + 2 chars, alternating 'a','b'
    first_len = n - k + 2
    res = []
    for i in range(first_len):
        res.append('a' if i % 2 == 0 else 'b')
    
    # Add remaining distinct chars starting from 'c'
    for i in range(2, k):
        res.append(chr(ord('a') + i))
    
    return ''.join(res)

def pack_string_to_int(s, max_chars=16):
    """Pack string into integer (8 bits per char)"""
    if s is None:
        # Return error marker: all 0xFF
        return (0xFF * (1 << (8 * max_chars))) - 1 if max_chars > 1 else 0xFF
    
    packed = 0
    for i, ch in enumerate(s[:max_chars]):
        packed |= (ord(ch) << (i * 8))
    return packed

def unpack_int_to_string(packed_int, n, max_chars=16):
    """Extract string from packed integer"""
    chars = []
    for i in range(max_chars):
        byte = (packed_int >> (i * 8)) & 0xFF
        if byte == 0xFF:  # Error marker
            chars.append(None)
        else:
            chars.append(chr(byte))
    return ''.join([c for c in chars if c is not None])

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_string_generator(dut):
    # Setup clock
    if not has_signal(dut, 'clk'):
        raise TestFailure("Module missing clk signal")
    
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases: (n, k, expected_string_or_None)
    test_cases = [
        (7, 4, "ababacd"),
        (4, 7, None),  # k > n
        (10, 5, "abababacde"),
        (100, 2, "ab" * 50),  # Too long, will be truncated in HDL
        (5, 3, "abacd"),
        (3, 3, "abc"),
        (1, 1, "a"),
        (1, 2, None),  # k > n
        (2, 2, "ab"),
        (2, 1, None),  # k=1, n>1
        (20, 5, "abababababababababacde"),
        (1000, 16, None),  # Too long, but error condition or truncated
    ]
    
    passed = 0
    failed = 0
    
    for i, (n, k, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: n={n}, k={k}, expected={expected}")
        
        try:
            # Clamp inputs to HDL width
            n_val = clamp_to_width(n, 16)
            k_val = clamp_to_width(k, 8)
            
            # Set inputs
            dut.n_in.value = n_val
            dut.k_in.value = k_val
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Check valid signal
            if not is_value_defined(dut.valid.value):
                raise TestFailure("Result valid signal undefined")
            
            valid = int(dut.valid.value)
            if valid == 0:
                # If expected is None, valid=0 might be okay, but our design should output valid=1 always
                raise TestFailure(f"valid signal is 0, expected 1 for test {i+1}")
            
            # Read result
            result_packed = safe_int(dut.result.value)
            
            # Unpack result to string (max 16 chars for HDL)
            actual_str = unpack_int_to_string(result_packed, n, max_chars=16)
            
            # For very long strings (n > 16), we only check first 16 chars or pattern
            if n > 16:
                # Check that first chars are correct pattern
                if expected is None:
                    # Should be error marker
                    if actual_str != "" and '0' in actual_str:
                         raise TestFailure(f"Expected error, got {actual_str}")
                else:
                    # Check first 16 chars match expected pattern
                    expected_prefix = expected[:16]
                    actual_prefix = actual_str[:16] if len(actual_str) >= 16 else actual_str
                    if actual_prefix != expected_prefix:
                        raise TestFailure(f"Prefix mismatch: expected {expected_prefix}, got {actual_prefix}")
            else:
                # Exact match for short strings
                if expected is None:
                    # Check for error marker (0xFF)
                    if result_packed != ((1 << (8*16)) - 1):
                        # Check if any byte is not 0xFF
                        is_error = True
                        for byte_pos in range(16):
                            byte = (result_packed >> (byte_pos * 8)) & 0xFF
                            if byte != 0xFF:
                                is_error = False
                                break
                        if not is_error:
                            raise TestFailure(f"Expected error marker, got {actual_str}")
                else:
                    if actual_str != expected:
                        raise TestFailure(f"Expected {expected}, got {actual_str}")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
            # Reset before next test
            await reset_dut(dut)
        
        # Small delay between tests
        await Timer(10, units='ns')
    
    cocotb.log.info(f"Tests passed: {passed}/{len(test_cases)}")
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_error_cases(dut):
    """Specific test for error conditions"""
    if not has_signal(dut, 'clk'):
        return
    
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test k > n
    dut.n_in.value = 5
    dut.k_in.value = 10
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await wait_for_done(dut)
    
    result = safe_int(dut.result.value)
    # Check for error marker (all 0xFF for first 16 bytes)
    is_error = True
    for byte_pos in range(16):
        byte = (result >> (byte_pos * 8)) & 0xFF
        if byte != 0xFF:
            is_error = False
            break
    
    if not is_error:
        raise TestFailure("k > n did not produce error marker")
    
    cocotb.log.info("Error case k > n passed")
    
    await reset_dut(dut)
    
    # Test k = 1, n > 1
    dut.n_in.value = 5
    dut.k_in.value = 1
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await wait_for_done(dut)
    
    result = safe_int(dut.result.value)
    is_error = True
    for byte_pos in range(16):
        byte = (result >> (byte_pos * 8)) & 0xFF
        if byte != 0xFF:
            is_error = False
            break
    
    if not is_error:
        raise TestFailure("k=1, n>1 did not produce error marker")
    
    cocotb.log.info("Error case k=1, n>1 passed")

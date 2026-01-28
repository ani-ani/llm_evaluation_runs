import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=256):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

def pack_string(chars, width=8):
    packed = 0
    for i, c in enumerate(chars):
        packed |= (ord(c) & ((1 << width) - 1)) << (i * width)
    return packed

def set_string_array(dut, name, string, max_len=16, width=8):
    """Set individual array elements for string characters"""
    for i in range(max_len):
        if i < len(string):
            getattr(dut, f"{name}_{i}").value = ord(string[i]) & ((1 << width) - 1)
        else:
            getattr(dut, f"{name}_{i}").value = 0

async def run_test_case(dut, a_str, b_str, expected):
    cocotb.log.info(f"Testing a='{a_str}', b='{b_str}' -> expected {expected}")
    
    # Set string lengths
    dut.len_a.value = len(a_str) & 0xF
    dut.len_b.value = len(b_str) & 0xF
    
    # Set string data
    set_string_array(dut, 'a', a_str)
    set_string_array(dut, 'b', b_str)
    
    # Start operation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion
    await wait_for_done(dut)
    
    # Read result
    if not is_value_defined(dut.result.value):
        raise TestFailure("Result undefined")
    
    result = int(dut.result.value)
    if result != expected:
        raise TestFailure(f"Expected {expected}, got {result}")

@cocotb.test(timeout_time=10, timeout_unit="ms")
async def test_cycpattern_check(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        # Setup clock (100MHz)
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational test
        await Timer(100, units='ns')

    # Test cases from specification
    test_cases = [
        ("xyzw", "xyw", 0),
        ("yello", "ell", 1),
        ("whattup", "ptut", 0),
        ("efef", "fee", 1),
        ("abab", "aabb", 0),
        ("winemtt", "tinem", 1),
        ("abcd", "abd", 0),
        ("hello", "ell", 1),
        ("whassup", "psus", 0),
        ("abab", "baa", 1),
        ("efef", "eeff", 0),
        ("himenss", "simen", 1),
    ]

    passed = failed = 0
    for i, (a, b, expected) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: '{a}' vs '{b}' (expected {expected})")
        try:
            await run_test_case(dut, a, b, expected)
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1

    if failed:
        raise TestFailure(f"{failed} out of {passed+failed} tests failed")

@cocotb.test(timeout_time=10, timeout_unit="ms")
async def test_edge_cases(dut):
    """Test edge cases"""
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    else:
        await Timer(100, units='ns')

    # Test: Empty-ish (single char)
    await run_test_case(dut, "a", "a", 1)
    # Test: No match at all
    await run_test_case(dut, "xyz", "uvw", 0)
    # Test: Rotation at boundary
    await run_test_case(dut, "abab", "aba", 1)
    # Test: Match at start of A
    await run_test_case(dut, "hello", "hel", 1)
    # Test: Match at end of A
    await run_test_case(dut, "hello", "llo", 1)

    cocotb.log.info("Edge case tests passed")

@cocotb.test(timeout_time=10, timeout_unit="ms")
async def test_rotation_only(dut):
    """Test cases where match requires rotation"""
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    else:
        await Timer(100, units='ns')

    # Rotation match cases
    await run_test_case(dut, "bca", "cab", 1)  # "cab" rotated to "abc" -> "bca" contains "bca"
    await run_test_case(dut, "abab", "baba", 1)  # "baba" rotated from "abab"
    await run_test_case(dut, "abcabc", "bcab", 1)

    cocotb.log.info("Rotation-only tests passed")
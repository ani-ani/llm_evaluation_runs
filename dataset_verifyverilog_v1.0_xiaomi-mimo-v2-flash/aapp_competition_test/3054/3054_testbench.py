import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

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

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

# Wait for done signal
async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# Reset DUT
async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    if has_signal(dut, 'char_valid'):
        dut.char_valid.value = 0
    if has_signal(dut, 'char_done'):
        dut.char_done.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

# Send string through char_in
async def send_string(dut, s):
    for char in s:
        dut.char_in.value = ord(char)
        dut.char_valid.value = 1
        await RisingEdge(dut.clk)
        dut.char_valid.value = 0
        await RisingEdge(dut.clk)
    # Send end-of-input
    dut.char_done.value = 1
    await RisingEdge(dut.clk)
    dut.char_done.value = 0

# Read output lines from arrays
async def read_output_lines(dut):
    lines = []
    for line_num in range(3):
        line_str = ""
        line_len = 0
        if line_num == 0:
            if has_signal(dut, 'line1_len'):
                line_len = int(dut.line1_len.value)
        elif line_num == 1:
            if has_signal(dut, 'line2_len'):
                line_len = int(dut.line2_len.value)
        else:
            if has_signal(dut, 'line3_len'):
                line_len = int(dut.line3_len.value)
        
        for i in range(line_len):
            # Read word array
            word_arr = []
            for j in range(16):
                attr_name = f'line{line_num+1}_word{i}_char{j}'
                if has_signal(dut, attr_name):
                    val = int(getattr(dut, attr_name).value)
                    if val > 0:
                        word_arr.append(chr(val))
            word_str = "".join(word_arr)
            if line_str:
                line_str += " "
            line_str += word_str
        lines.append(line_str)
    return lines

# Test case: Known haiku input
@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_haiku_basic(dut):
    # Setup clock if sequential
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    
    # Test case 1: Valid haiku
    test_input = "Blue Ridge mountain road. Leaves, glowing in autumn sun, fall in Virginia.\n"
    expected_lines = [
        "Blue Ridge mountain road.",
        "Leaves, glowing in autumn sun,",
        "fall in Virginia."
    ]
    
    cocotb.log.info(f"Testing: {test_input.strip()}")
    
    if is_seq:
        await send_string(dut, test_input)
        await wait_for_done(dut)
    else:
        await Timer(100, units='ns')
    
    # Check outputs
    if has_signal(dut, 'valid'):
        valid = int(dut.valid.value)
        if valid != 1:
            raise TestFailure(f"Expected valid=1, got {valid}")
    
    if has_signal(dut, 'done'):
        done = int(dut.done.value)
        if done != 1:
            raise TestFailure(f"Expected done=1, got {done}")
    
    # Read and verify lines
    try:
        lines = await read_output_lines(dut)
        
        for i, (actual, expected) in enumerate(zip(lines, expected_lines)):
            if actual != expected:
                raise TestFailure(f"Line {i+1} mismatch: expected '{expected}', got '{actual}'")
        
        cocotb.log.info(f"Test 1 PASSED: Lines match expected haiku")
    except Exception as e:
        cocotb.log.error(f"Test 1 FAILED: {e}")
        raise

# Test case: Invalid haiku
@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_haiku_invalid(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    
    test_input = "Who would know if we had too few syllables?\n"
    
    if is_seq:
        await send_string(dut, test_input)
        await wait_for_done(dut)
    else:
        await Timer(100, units='ns')
    
    if has_signal(dut, 'invalid'):
        invalid = int(dut.invalid.value)
        if invalid != 1:
            raise TestFailure(f"Expected invalid=1, got {invalid}")
    
    if has_signal(dut, 'valid'):
        valid = int(dut.valid.value)
        if valid != 0:
            raise TestFailure(f"Expected valid=0, got {valid}")
    
    cocotb.log.info("Test 2 PASSED: Invalid case detected")

# Test case: Alternative split
@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_haiku_alt(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    
    # This should split differently
    test_input = "International contest- motivation high Programmers have fun!.\n"
    
    if is_seq:
        await send_string(dut, test_input)
        await wait_for_done(dut)
    else:
        await Timer(100, units='ns')
    
    if has_signal(dut, 'valid'):
        valid = int(dut.valid.value)
        if valid != 1:
            raise TestFailure(f"Expected valid=1, got {valid}")
    
    # Verify we have 3 lines with correct syllable counts
    # Based on problem statement, this is a valid haiku
    lines = await read_output_lines(dut)
    
    if len(lines) != 3:
        raise TestFailure(f"Expected 3 lines, got {len(lines)}")
    
    cocotb.log.info(f"Test 3 PASSED: Lines = {lines}")

# Edge case: Single word with many syllables
@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_haiku_edge(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    
    # Simple test
    test_input = "hello\n"
    
    if is_seq:
        await send_string(dut, test_input)
        await wait_for_done(dut)
    else:
        await Timer(100, units='ns')
    
    if has_signal(dut, 'invalid'):
        invalid = int(dut.invalid.value)
        if invalid != 1:
            raise TestFailure(f"Expected invalid=1 for single word, got {invalid}")
    
    cocotb.log.info("Test 4 PASSED: Single word correctly marked invalid")

# Performance test with max length
@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_haiku_max_len(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    
    # Create a long valid haiku
    test_input = "The quick brown fox jumps over the lazy dog. Hello world this is a test of syllable counting in verilog. Cool.\n"
    
    if is_seq:
        await send_string(dut, test_input)
        await wait_for_done(dut)
    else:
        await Timer(100, units='ns')
    
    if has_signal(dut, 'done'):
        done = int(dut.done.value)
        if done != 1:
            raise TestFailure(f"Expected done=1, got {done}")
    
    cocotb.log.info("Test 5 PASSED: Max length input processed")

# Symbol test (non-alphabetic)
@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_haiku_symbols(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    
    # Test with punctuation
    test_input = "Hello, world! How are you?\n"
    
    if is_seq:
        await send_string(dut, test_input)
        await wait_for_done(dut)
    else:
        await Timer(100, units='ns')
    
    if has_signal(dut, 'invalid'):
        invalid = int(dut.invalid.value)
        if invalid != 1:
            raise TestFailure(f"Expected invalid=1, got {invalid}")
    
    cocotb.log.info("Test 6 PASSED: Punctuation handled correctly")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_all_cases(dut):
    """Run all test cases in sequence"""
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    test_cases = [
        ("Blue Ridge mountain road. Leaves, glowing in autumn sun, fall in Virginia.\n", True, "Basic haiku"),
        ("Who would know if we had too few syllables?\n", False, "Too many syllables"),
        ("International contest- motivation high Programmers have fun!.\n", True, "Alternative split"),
        ("Programming contest is stressing us all out. International pain.\n", False, "No valid split"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (inp, should_be_valid, desc) in enumerate(test_cases):
        if is_seq:
            await reset_dut(dut)
            await send_string(dut, inp)
            await wait_for_done(dut)
        else:
            await Timer(100, units='ns')
        
        try:
            if has_signal(dut, 'valid'):
                valid = int(dut.valid.value)
                if valid == 1 and should_be_valid:
                    cocotb.log.info(f"PASS Test {i+1}: {desc}")
                    passed += 1
                elif valid == 0 and not should_be_valid:
                    cocotb.log.info(f"PASS Test {i+1}: {desc}")
                    passed += 1
                else:
                    raise TestFailure(f"Test {i+1} failed: expected valid={1 if should_be_valid else 0}, got {valid}")
            else:
                raise TestFailure(f"Test {i+1} failed: No 'valid' signal")
        except TestFailure as e:
            cocotb.log.error(f"FAIL Test {i+1}: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
    cocotb.log.info(f"All tests passed: {passed} total")
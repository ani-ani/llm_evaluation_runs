import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration
DATA_WIDTH = 8
RESULT_WIDTH = 16
CLK_PERIOD_NS = 10
MAX_CYCLES = 100

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

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    if has_signal(dut, 'valid'):
        dut.valid.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_substring_counter_combinational(dut):
    if has_signal(dut, 'clk') or has_signal(dut, 'done'):
        dut._log.info("Skipping combinational test - sequential module detected")
        return
    
    test_cases = [
        (3, 6, "abc -> 3 chars"),
        (4, 10, "abcd -> 4 chars"),
        (5, 15, "abcde -> 5 chars"),
        (0, 0, "empty string"),
        (1, 1, "single char"),
        (8, 36, "max length 8"),
    ]
    
    passed = 0
    failed = 0
    
    for str_len, expected, description in test_cases:
        dut._log.info(f"Test: {description}")
        try:
            dut.str_len.value = str_len
            await Timer(10, units='ns')
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined (X/Z)")
            result = int(dut.result.value)
            if result != expected:
                raise TestFailure(f"str_len={str_len}: expected {expected}, got {result}")
            dut._log.info(f"  PASS: str_len={str_len} -> {result}")
            passed += 1
        except TestFailure as e:
            dut._log.error(f"  FAIL: {e}")
            failed += 1
    
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_substring_counter_sequential(dut):
    if not (has_signal(dut, 'clk') and has_signal(dut, 'done')):
        dut._log.info("Skipping sequential test - combinational module detected")
        return
    
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    await reset_dut(dut)
    
    test_cases = [
        ([ord('a'), ord('b'), ord('c')], 6, "abc"),
        ([ord('a'), ord('b'), ord('c'), ord('d')], 10, "abcd"),
        ([ord('a'), ord('b'), ord('c'), ord('d'), ord('e')], 15, "abcde"),
        ([ord('x')], 1, "x"),
    ]
    
    passed = 0
    failed = 0
    
    for char_list, expected, description in test_cases:
        dut._log.info(f"Test: {description}")
        try:
            await reset_dut(dut)
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            for char in char_list:
                dut.char_in.value = char
                dut.valid.value = 1
                await RisingEdge(dut.clk)
            dut.valid.value = 0
            await wait_for_done(dut)
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined (X/Z)")
            result = int(dut.result.value)
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            dut._log.info(f"  PASS: {description} -> {result}")
            passed += 1
        except TestFailure as e:
            dut._log.error(f"  FAIL: {e}")
            failed += 1
    
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
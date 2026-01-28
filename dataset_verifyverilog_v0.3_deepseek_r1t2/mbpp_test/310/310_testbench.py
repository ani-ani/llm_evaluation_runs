import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
INDEX_WIDTH = 3
COUNT_WIDTH = 4
CLK_PERIOD_NS = 10
MAX_CYCLES = 500

# ============================================================================
# HELPER FUNCTIONS
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

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    if has_signal(dut, 'load_valid'):
        dut.load_valid.value = 0
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

async def load_string(dut, test_string):
    padded = (test_string + '\x00' * 8)[:8]
    for i, char in enumerate(padded):
        dut.char_in.value = ord(char)
        dut.char_index.value = i
        dut.load_valid.value = 1
        await RisingEdge(dut.clk)
    dut.load_valid.value = 0
    await RisingEdge(dut.clk)

async def process_and_read(dut):
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    results = []
    for _ in range(8):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.valid_out.value) and int(dut.valid_out.value) == 1:
            if is_value_defined(dut.char_out.value):
                results.append(int(dut.char_out.value))
    await wait_for_done(dut)
    count = int(dut.count.value) if is_value_defined(dut.count.value) else 0
    return results, count

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_string_to_tuple(dut):
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    await reset_dut(dut)
    
    test_cases = [
        ("py 3.0", [ord('p'), ord('y'), ord('3'), ord('.'), ord('0')], "Filter spaces"),
        ("item1", [ord('i'), ord('t'), ord('e'), ord('m'), ord('1')], "No spaces"),
        ("15.10", [ord('1'), ord('5'), ord('.'), ord('1'), ord('0')], "Numbers only"),
        ("a b c", [ord('a'), ord('b'), ord('c')], "Multiple spaces"),
        ("     x", [ord('x')], "Leading spaces"),
        ("x     ", [ord('x')], "Trailing spaces"),
        ("        ", [], "All spaces"),
        ("12345678", [ord('1'), ord('2'), ord('3'), ord('4'), ord('5'), ord('6'), ord('7'), ord('8')], "8 chars no spaces"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (input_str, expected_chars, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        cocotb.log.info(f"  Input: '{input_str}', Expected: {[chr(c) for c in expected_chars]}")
        
        try:
            await load_string(dut, input_str)
            results, count = await process_and_read(dut)
            
            expected_count = len(expected_chars)
            if count != expected_count:
                raise TestFailure(f"Count mismatch: expected {expected_count}, got {count}")
            
            if len(results) != len(expected_chars):
                raise TestFailure(f"Output length mismatch: expected {len(expected_chars)}, got {len(results)}")
            
            for j, (expected, actual) in enumerate(zip(expected_chars, results)):
                if expected != actual:
                    raise TestFailure(f"Char {j}: expected {chr(expected)} ({expected}), got {chr(actual)} ({actual})")
            
            cocotb.log.info(f"  PASS")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")

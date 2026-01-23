import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
MAX_NAMES = 8
MAX_NAME_LEN = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

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

# ============================================================================
# ARRAY WRITE HELPERS
# ============================================================================

async def write_name(dut, name_idx, name_str):
    padded = (name_str + '\0' * MAX_NAME_LEN)[:MAX_NAME_LEN]
    for char_idx, char in enumerate(padded):
        port_name = f"names_{name_idx}_{char_idx}"
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = ord(char)
        else:
            raise TestFailure(f"Signal {port_name} not found")

async def write_names(dut, names):
    padded_names = names[:MAX_NAMES] + [''] * (MAX_NAMES - len(names))
    for i, name in enumerate(padded_names):
        await write_name(dut, i, name)

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    dut.start.value = 0
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

async def start_computation(dut):
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_string_length_sum(dut):
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases: (names_list, expected_sum, description)
    test_cases = [
        (["sally", "Dylan", "rebecca", "Diana", "Joanne", "keith"], 16, "Test 1"),
        (["php", "res", "Python", "abcd", "Java", "aaa"], 10, "Test 2"),
        (["abcd", "Python", "abba", "aba"], 6, "Test 3"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (names, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        
        try:
            await write_names(dut, names)
            await start_computation(dut)
            await wait_for_done(dut)
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined")
            
            result = int(dut.result.value)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")

import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

DATA_WIDTH = 16
RESULT_WIDTH = 32
CLK_NS = 10
MAX_CYCLES = 200

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

def calculate_expected(str_len):
    return int(str_len * (str_len + 1) / 2)

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_substring_count(dut):
    # Check if sequential
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational - just set inputs
        dut.rst_n.value = 1
    
    # Test cases from Python
    test_cases = [
        (3, 6, "abc"),
        (4, 10, "abcd"),
        (5, 15, "abcde"),
        (0, 0, "empty"),
        (1, 1, "a"),
        (100, 5050, "100 chars"),
        (65535, 2147479040, "max length"),
        (65534, 2147413515, "near max")
    ]
    
    passed = 0
    failed = 0
    
    for i, (str_len, exp, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc} (len={str_len})")
        try:
            # Set input
            dut.str_len.value = clamp_to_width(str_len, DATA_WIDTH)
            
            if is_seq:
                # Trigger computation
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                # Combinational, wait for propagation
                await Timer(10, units='ns')
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            if result != exp:
                raise TestFailure(f"Expected {exp}, got {result}")
            
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL (Test {i+1} - {desc}): {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_random_values(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        dut.rst_n.value = 1
    
    # Generate 20 random test cases
    random.seed(42)
    test_cases = []
    for _ in range(20):
        n = random.randint(0, 10000)
        exp = calculate_expected(n)
        test_cases.append((n, exp, f"random_{n}"))
    
    passed = 0
    failed = 0
    
    for i, (str_len, exp, desc) in enumerate(test_cases):
        cocotb.log.info(f"Random test {i+1}: {desc}")
        try:
            dut.str_len.value = clamp_to_width(str_len, DATA_WIDTH)
            
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut, max_cycles=50)
            else:
                await Timer(10, units='ns')
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            if result != exp:
                raise TestFailure(f"Expected {exp}, got {result}")
            
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL (Test {i+1}): {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} random tests failed, {passed} passed")

@cocotb.test(timeout_time=500, timeout_unit="ms")
async def test_reset_behavior(dut):
    is_seq = has_signal(dut, 'clk')
    if not is_seq:
        cocotb.log.info("Test skipped: Combinational module")
        return
    
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    # Reset high
    dut.rst_n.value = 1
    dut.start.value = 1
    dut.str_len.value = 5
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait a bit, then reset
    await Timer(50, units='ns')
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    
    # Check outputs are zero
    if is_value_defined(dut.done.value) and int(dut.done.value) != 0:
        raise TestFailure(f"Reset failed: done should be 0, got {int(dut.done.value)}")
    if is_value_defined(dut.result.value) and int(dut.result.value) != 0:
        raise TestFailure(f"Reset failed: result should be 0, got {int(dut.result.value)}")
    
    # Release reset
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Should now compute correctly
    dut.str_len.value = 3
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    await wait_for_done(dut)
    
    if int(dut.result.value) != 6:
        raise TestFailure(f"After reset, expected 6, got {int(dut.result.value)}")

@cocotb.test(timeout_time=500, timeout_unit="ms")
async def test_done_pulse(dut):
    is_seq = has_signal(dut, 'clk')
    if not is_seq:
        cocotb.log.info("Test skipped: Combinational module")
        return
    
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Trigger computation
    dut.str_len.value = 4
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    for _ in range(50):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            # Done should be a 1-cycle pulse
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                raise TestFailure("done signal should be 1-cycle pulse, but remained high")
            break
    else:
        raise TestFailure("done signal never went high")

import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helper functions
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

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    if has_signal(dut, 'n'): dut.n.value = 0
    for _ in range(cycles):
        if has_signal(dut, 'clk'): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    if has_signal(dut, 'clk'): await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=20):
    for _ in range(max_cycles):
        if has_signal(dut, 'clk'):
            await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# Lucas number reference function
def find_lucas(n):
    if n == 0: return 2
    if n == 1: return 1
    a, b = 2, 1
    for _ in range(2, n + 1):
        a, b = b, a + b
    return b

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_lucas(dut):
    CLK_NS = 10
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases from specification + edge cases
    test_cases = [
        (0, 2, "n=0"),
        (1, 1, "n=1"),
        (3, 4, "n=3"),
        (4, 7, "n=4"),
        (9, 76, "n=9"),
        (15, 1364, "n=15")  # Maximum valid n
    ]
    
    passed = 0
    failed = 0
    
    for i, (n_val, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            if is_seq:
                # Apply inputs
                dut.n.value = clamp_to_width(n_val, 4)
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for completion
                await wait_for_done(dut, max_cycles=20)
                
                # Read result
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result undefined")
                result = int(dut.result.value)
            else:
                # Combinational
                dut.n.value = clamp_to_width(n_val, 4)
                await Timer(1, units='ns')
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result undefined")
                result = int(dut.result.value)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            passed += 1
            cocotb.log.info(f"PASS: {desc}")
        except TestFailure as e:
            cocotb.log.error(f"FAIL {desc}: {e}")
            failed += 1
    
    # Additional random test
    cocotb.log.info("Random test...")
    for _ in range(5):
        n_val = random.randint(0, 15)
        expected = find_lucas(n_val)
        try:
            if is_seq:
                dut.n.value = clamp_to_width(n_val, 4)
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut, max_cycles=20)
                result = int(dut.result.value)
            else:
                dut.n.value = clamp_to_width(n_val, 4)
                await Timer(1, units='ns')
                result = int(dut.result.value)
            if result != expected:
                raise TestFailure(f"Random n={n_val}: expected {expected}, got {result}")
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL random: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")

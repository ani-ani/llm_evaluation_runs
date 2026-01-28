import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

DATA_WIDTH = 16
CLK_NS = 10
MAX_CYCLES = 1000

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

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits - 1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def gcd(a, b):
    """Reference implementation of Euclidean GCD"""
    while b:
        a, b = b, a % b
    return a

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_gcd(dut):
    # Setup clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational module
        await Timer(100, units='ns')

    # Test cases: (a, b, expected_gcd)
    test_cases = [
        (3, 7, 1),
        (10, 15, 5),
        (49, 14, 7),
        (144, 60, 12),
        (0, 5, 5),
        (12345, 67890, 15),  # GCD(12345, 67890) = 15
        (255, 256, 1),
        (1000, 1000, 1000),  # Same number
        (1, 1, 1),
    ]

    passed = 0
    failed = 0

    for i, (a, b, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: GCD({a}, {b})")
        try:
            # Set inputs
            dut.a.value = clamp_to_width(a, DATA_WIDTH)
            dut.b.value = clamp_to_width(b, DATA_WIDTH)
            
            if has_signal(dut, 'clk'):
                # Sequential logic
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
                
                # Check result
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result signal undefined")
                
                result = int(dut.result.value)
                if result != expected:
                    raise TestFailure(f"Expected GCD={expected}, got {result}")
            else:
                # Combinational logic
                await Timer(10, units='ns')
                result = int(dut.result.value)
                if result != expected:
                    raise TestFailure(f"Expected GCD={expected}, got {result}")
            
            passed += 1
            cocotb.log.info(f"  PASS: GCD={result}")
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1

    # Random test cases
    for i in range(10):
        a = random.randint(1, 1000)
        b = random.randint(1, 1000)
        expected = gcd(a, b)
        
        cocotb.log.info(f"Random Test {i+1}: GCD({a}, {b})")
        try:
            dut.a.value = clamp_to_width(a, DATA_WIDTH)
            dut.b.value = clamp_to_width(b, DATA_WIDTH)
            
            if has_signal(dut, 'clk'):
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
                result = int(dut.result.value)
            else:
                await Timer(10, units='ns')
                result = int(dut.result.value)
            
            if result != expected:
                raise TestFailure(f"Expected GCD={expected}, got {result}")
            
            passed += 1
            cocotb.log.info(f"  PASS: GCD={result}")
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1

    # Edge cases
    edge_cases = [
        (0, 0, 0),  # Both zero - undefined mathematically, but we define as 0
        (0, 1, 1),
        (65535, 1, 1),  # Max 16-bit value
        (65535, 65535, 65535),
    ]

    for i, (a, b, expected) in enumerate(edge_cases):
        cocotb.log.info(f"Edge Case {i+1}: GCD({a}, {b})")
        try:
            dut.a.value = clamp_to_width(a, DATA_WIDTH)
            dut.b.value = clamp_to_width(b, DATA_WIDTH)
            
            if has_signal(dut, 'clk'):
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
                result = int(dut.result.value)
            else:
                await Timer(10, units='ns')
                result = int(dut.result.value)
            
            if result != expected:
                raise TestFailure(f"Expected GCD={expected}, got {result}")
            
            passed += 1
            cocotb.log.info(f"  PASS: GCD={result}")
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1

    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")

    cocotb.log.info(f"\n{passed} tests passed")

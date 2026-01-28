import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration
DATA_WIDTH = 64
MAX_CYCLES = 1000
CLK_PERIOD_NS = 10

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

def to_signed(val, bits):
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    if val < 0:
        return val + (1 << bits)
    return val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut):
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_m_perfect_checker(dut):
    """Test m-perfect checker module"""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (x, y, m, expected_result, description)
    test_cases = [
        (1, 2, 5, 2, "Sample 1: 1,2 -> 5"),
        (-1, 4, 15, 4, "Sample 2: -1,4 -> 15"),
        (0, -1, 5, -1, "Sample 3: 0,-1 -> 5 (impossible)"),
        (0, 1, 8, 5, "0,1 -> 8"),
        (-134, -345, -134, 0, "Both negative, target reached"),
        (-134, -345, -133, -1, "Both negative, target not reached"),
        (999999999, -1000000000, 1000000000, 3, "Large numbers"),
        (0, 0, 0, 0, "Zero case"),
        (0, 0, 1, -1, "Zero impossible"),
        (-1000000000000000000, 1, 1000000000000000000, 1000000000000000087, "Extreme values"),
        (-3, 26, -1, 0, "Target reached immediately"),
        (-25, 4, -8, 0, "Target reached immediately 2"),
        (12, 30, -8, 0, "Both positive, target negative"),
        (-12, 17, 3, 0, "Mixed, target small positive"),
        (4, -11, 28, 8, "Negative becomes positive"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (x, y, m, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        cocotb.log.info(f"  Input: x={x}, y={y}, m={m}")
        cocotb.log.info(f"  Expected: {expected}")
        
        try:
            # Set inputs
            dut.x_in.value = from_signed(x, DATA_WIDTH)
            dut.y_in.value = from_signed(y, DATA_WIDTH)
            dut.m_in.value = from_signed(m, DATA_WIDTH)
            
            # Start computation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure(f"Result is undefined (X/Z)")
            
            raw_result = int(dut.result.value)
            actual = to_signed(raw_result, 32)
            
            if actual != expected:
                raise TestFailure(f"Expected {expected}, got {actual}")
            
            cocotb.log.info(f"  PASS: result = {actual}")
            passed += 1
            
            # Reset for next test
            await reset_dut(dut)
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
            await reset_dut(dut)
    
    # Summary
    cocotb.log.info(f"{'='*60}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
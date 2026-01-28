import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# MANDATORY HELPER FUNCTIONS
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

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    if value < 0:
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# ============================================================================
# SEQUENTIAL MODULE HELPERS
# ============================================================================

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=100):
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

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_cinema_seating(dut):
    """Test the cinema_seating module with adapted inputs."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (n, c1, c2, c3, expected_result, description)
    test_cases = [
        (3, 0, 1, 1, 3, "Sample 1: groups 0 solo, 1 pair, 1 trio -> X=3"),
        (3, 2, 1, 1, 4, "Sample 2: 2 solo, 1 pair, 1 trio -> X=4"),
        # Additional cases to verify lookup table
        (1, 0, 0, 0, 1, "No groups -> X=1"),
        (1, 1, 0, 0, 1, "One solo -> X=1"),
        (1, 2, 0, 0, 2, "Two solos -> X=2"),
        (2, 0, 1, 0, 2, "One pair -> X=2"),
        (2, 1, 1, 0, 2, "One pair + one solo -> X=2"),
        (2, 2, 1, 0, 3, "Two solos + one pair -> X=3"),
        (2, 0, 2, 0, 3, "Two pairs -> X=3"),
        (3, 1, 0, 1, 3, "One solo + one trio -> X=3"),
        (3, 1, 1, 1, 3, "One solo + one pair + one trio -> X=3"),
        (3, 2, 1, 1, 4, "Two solos + one pair + one trio -> X=4"),
        (3, 0, 2, 1, 4, "Two pairs + one trio -> X=4"),
        (3, 1, 2, 1, 4, "One solo + two pairs + one trio -> X=4"),
        (3, 2, 2, 2, 5, "Two of each -> impossible (X>4)"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n, c1, c2, c3, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        
        # Set inputs
        dut.n.value = n
        dut.c1.value = c1
        dut.c2.value = c2
        dut.c3.value = c3
        
        # Start computation
        await start_computation(dut)
        await wait_for_done(dut)
        
        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Result is undefined (X/Z)")
        
        result = int(dut.result.value)
        
        if result != expected:
            cocotb.log.error(f"  FAIL: expected {expected}, got {result}")
            failed += 1
        else:
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")

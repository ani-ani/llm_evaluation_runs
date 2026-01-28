import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

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

# Test parameters
DATA_WIDTH = 32
ARRAY_SIZE = 16
CLK_NS = 10
MAX_CYCLES = 600

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

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_scheduling(dut):
    # Setup clock and reset
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases: (n, k, shows_list, expected_result, description)
    test_cases = [
        (3, 1, [(1,2), (2,3), (2,3)], 2, "Sample 1: k=1"),
        (4, 1, [(1,3), (4,6), (7,8), (2,5)], 3, "Sample 2: k=1"),
        (5, 2, [(1,4), (5,9), (2,7), (3,8), (6,10)], 3, "Sample 3: k=2"),
        (2, 1, [(0,10), (5,15)], 1, "Edge: overlapping"),
        (4, 2, [(1,3), (2,4), (3,5), (4,6)], 4, "Edge: all sequential"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n, k, shows, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Write inputs
            dut.n.value = n
            dut.k.value = k
            
            # Fill arrays
            for j in range(ARRAY_SIZE):
                if j < len(shows):
                    x_val = shows[j][0]
                    y_val = shows[j][1]
                    # Clamp and assign
                    dut.x[j].value = clamp_to_width(to_signed(x_val, 32) & 0xFFFFFFFF, 32)
                    dut.y[j].value = clamp_to_width(to_signed(y_val, 32) & 0xFFFFFFFF, 32)
                else:
                    dut.x[j].value = 0
                    dut.y[j].value = 0
            
            # Start computation
            await RisingEdge(dut.clk)
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
            
            passed += 1
            cocotb.log.info(f"PASS: {desc}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: Test {i+1}: {e}")
            failed += 1
            
    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")
    
    cocotb.log.info(f"All {passed} tests passed")

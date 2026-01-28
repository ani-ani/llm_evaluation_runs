import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
MAX_POINTS = 16
CLK_NS = 10
MAX_CYCLES = 256

# Helpers
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

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def feed_points(dut, points):
    """Feed points sequentially over cycles."""
    # Assuming inputs: x_i, y_i (8-bit each), valid_i, done_i
    dut.valid_i.value = 0
    dut.done_i.value = 0
    for i in range(len(points)):
        x, y = points[i]
        dut.x_i.value = clamp_to_width(x, DATA_WIDTH)
        dut.y_i.value = clamp_to_width(y, DATA_WIDTH)
        dut.valid_i.value = 1
        await RisingEdge(dut.clk)
        dut.valid_i.value = 0
        # Optional delay between points
        await RisingEdge(dut.clk)
    dut.done_i.value = 1
    await RisingEdge(dut.clk)
    dut.done_i.value = 0

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_strange_rectangle(dut):
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test case 1: 3 points on same x (Example 1)
    test_cases = [
        ([ (1,1), (1,2), (1,3) ], 3, "Vertical line"),
        ([ (1,1), (2,1), (3,1) ], 6, "Horizontal line"),
        ([ (2,1), (2,2), (3,1), (3,2) ], 6, "2x2 grid"),
        ([ (1,1) ], 1, "Single point"),
        ([ (1,1), (2,2), (3,3), (4,4), (5,5) ], 25, "Diagonal 5 points"),
    ]
    
    for pts, exp, desc in test_cases:
        cocotb.log.info(f"Test: {desc}, expecting {exp}")
        
        # Start signal
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Feed points
        await feed_points(dut, pts)
        
        # Wait for done
        await wait_for_done(dut)
        
        # Check result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Result undefined for {desc}")
        
        result = int(dut.result.value)
        if result != exp:
            raise TestFailure(f"{desc}: Expected {exp}, got {result}")
        
        # Reset for next test
        await reset_dut(dut)
    
    cocotb.log.info("All tests passed!")

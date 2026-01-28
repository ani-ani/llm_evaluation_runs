import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 32
CLK_NS = 10
MAX_CYCLES = 10000

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
    if has_signal(dut, 'rect_valid'): dut.rect_valid.value = 0
    if has_signal(dut, 'rect_done'): dut.rect_done.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def load_rect(dut, x1, y1, x2, y2):
    dut.rect_x1.value = clamp_to_width(x1, DATA_WIDTH)
    dut.rect_y1.value = clamp_to_width(y1, DATA_WIDTH)
    dut.rect_x2.value = clamp_to_width(x2, DATA_WIDTH)
    dut.rect_y2.value = clamp_to_width(y2, DATA_WIDTH)
    dut.rect_valid.value = 1
    await RisingEdge(dut.clk)
    dut.rect_valid.value = 0

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_min_cost_white(dut):
    # Setup clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases: List of (list_of_rects, expected_cost, description)
    # Rect format: (x1, y1, x2, y2)
    test_cases = [
        ([(4, 1, 5, 10), (1, 4, 10, 5)], 4, "Example 1"),
        ([(2, 1, 2, 1), (4, 2, 4, 3), (2, 5, 2, 5), (2, 3, 5, 3), (1, 2, 1, 2), (3, 2, 5, 3)], 3, "Example 2"),
        ([], 0, "Empty"),
        ([(1, 1, 2, 2)], 2, "Single square"),
        ([(1, 1, 10, 1)], 1, "Single row"),
        ([(1, 1, 1, 10)], 1, "Single col")
    ]
    
    passed = 0
    failed = 0
    
    for rects, expected, desc in test_cases:
        cocotb.log.info(f"Running test: {desc}")
        try:
            # Start computation
            if has_signal(dut, 'start'):
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
            
            # Load rectangles
            for rect in rects:
                await load_rect(dut, rect[0], rect[1], rect[2], rect[3])
            
            # Signal end
            dut.rect_done.value = 1
            await RisingEdge(dut.clk)
            dut.rect_done.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Check result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            cocotb.log.info(f"PASS: {desc} (Result: {result})")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {desc} - {e}")
            failed += 1
            
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")

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

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

# Constants
DATA_WIDTH = 13  # Q12.4 range approx -4000 to 4000
MAX_POINTS = 8
CLK_NS = 10
MAX_CYCLES = 2000

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(2): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def scale_and_assign_points(dut, points):
    # Scale points to fit 13-bit signed (approx -4000 to 4000)
    # Original range -20000 to 20000. Scale by 5 to fit -4000 to 4000
    scaled_points = [(x // 5, y // 5) for x, y in points]
    
    for i in range(MAX_POINTS):
        if i < len(points):
            x, y = scaled_points[i]
        else:
            x, y = 0, 0
        
        # Handle signed to unsigned conversion for Verilog assignment
        # 13 bits: max 4095
        x_val = x if x >= 0 else (1 << DATA_WIDTH) + x
        y_val = y if y >= 0 else (1 << DATA_WIDTH) + y
        
        if has_signal(dut, f'pt_x_{i}'):
            getattr(dut, f'pt_x_{i}').value = x_val
            getattr(dut, f'pt_y_{i}').value = y_val
        elif has_signal(dut, f'pt_x'):
            # Packed or array - assuming unpacked array for simplicity in test
            dut.pt_x[i].value = x_val
            dut.pt_y[i].value = y_val

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_symmetry(dut):
    # Clock setup
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases adapted to small scale
    # Case 1: Square (Point symmetric) -> 0 additions
    # Scaled: (0,0), (200,0), (0,200), (200,200)
    case1 = [(0, 0), (1000, 0), (0, 1000), (1000, 1000)]
    
    # Case 2: Line symmetric (Vertical) -> 0 additions
    # (0,0), (0,10)
    case2 = [(0, 0), (0, 10)]

    # Case 3: Random non-symmetric -> small number
    case3 = [(0, 0), (10, 5), (20, 10)]

    test_cases = [
        (case1, 0, "Square (Point Sym)"),
        (case2, 0, "Vertical Line"),
        (case3, 1, "Triangle (Point Sym)"),
    ]

    passed = 0
    failed = 0

    for i, (points, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Running Test {i+1}: {desc}")
        try:
            # Load inputs
            await scale_and_assign_points(dut, points)
            
            if has_signal(dut, 'len'):
                dut.len.value = len(points)
            
            # Start
            if has_signal(dut, 'start'):
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                await wait_for_done(dut, 1500) # 8 points logic takes time
                
                # Read result
                if is_value_defined(dut.result.value):
                    result = int(dut.result.value)
                    cocotb.log.info(f"Expected {expected}, Got {result}")
                    if result != expected:
                        raise TestFailure(f"Result mismatch: Expected {expected}, Got {result}")
                else:
                    raise TestFailure("Result is undefined")
            else:
                # Combinational (should be instant)
                await Timer(50, units='ns')
                result = int(dut.result.value)
                if result != expected:
                     raise TestFailure(f"Result mismatch: Expected {expected}, Got {result}")

            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"Test {i+1} Failed: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed")

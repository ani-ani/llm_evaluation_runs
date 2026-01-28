import cocotb
from cocotb.triggers import Timer, RisingEdge, Combine
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
    min_val = -(1 << (bits-1))
    max_val = (1 << (bits-1)) - 1
    return min(max_val, max(min_val, v))

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    if has_signal(dut, 'valid_in'): dut.valid_in.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=200):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def load_points(dut, points):
    """Load 16 points via x_in/y_in with valid_in pulses"""
    for i in range(16):
        if i < len(points):
            x_val = clamp_to_width(points[i][0], 16)
            y_val = clamp_to_width(points[i][1], 16)
            dut.x_in.value = x_val
            dut.y_in.value = y_val
        else:
            dut.x_in.value = 0
            dut.y_in.value = 0
        
        dut.valid_in.value = 1
        await RisingEdge(dut.clk)
        dut.valid_in.value = 0
        await RisingEdge(dut.clk)
    
    # Signal load complete
    dut.load_done.value = 1
    await RisingEdge(dut.clk)
    dut.load_done.value = 0

# Test cases from problem examples
test_cases = [
    {
        "points": [(-1,0), (0,0), (1,0), (-1,1), (0,2), (1,1)],
        "expected": 0,  # failure
        "desc": "Sample 1: 6 points not coverable"
    },
    {
        "points": [(1,1), (3,5), (0,-1), (1,0), (5,0), (0,0)],
        "expected": 1,  # success
        "desc": "Sample 2: 6 points coverable"
    },
    {
        "points": [(1,1), (3,5), (0,-1), (1,0), (5,0), (0,1)],
        "expected": 0,  # failure
        "desc": "Sample 3: 6 points not coverable"
    },
    {
        "points": [(6,1), (3,5), (0,-1), (1,0), (6,0), (0,0)],
        "expected": 0,  # failure
        "desc": "Sample 4: 6 points not coverable"
    },
    {
        "points": [(0,0), (1,1), (2,2), (3,3)],
        "expected": 1,  # success
        "desc": "Simple line: 4 collinear points"
    },
    {
        "points": [(0,0), (1,0), (0,1), (1,1)],
        "expected": 1,  # success (2 horizontal lines)
        "desc": "Square: 4 points in rectangle"
    },
]

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_laser_shots(dut):
    # Setup clock if present
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    passed = 0
    failed = 0
    
    for tc_idx, tc in enumerate(test_cases):
        cocotb.log.info(f"\nTest {tc_idx+1}: {tc['desc']}")
        cocotb.log.info(f"Points: {tc['points']}")
        
        try:
            # Check if we need to handle fewer than 16 points
            if len(tc['points']) > 16:
                tc['points'] = tc['points'][:16]
            
            # Wait for IDLE state
            if has_signal(dut, 'state_debug'):
                for _ in range(10):
                    await RisingEdge(dut.clk)
                    if int(dut.state_debug.value) == 0:
                        break
            
            # Start processing
            if has_signal(dut, 'start'):
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
            
            # Load points
            await load_points(dut, tc['points'])
            
            # Wait for done
            await wait_for_done(dut, max_cycles=300)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            result = int(dut.result.value)
            expected = tc['expected']
            
            cocotb.log.info(f"Expected: {expected}, Got: {result}")
            
            if result == expected:
                cocotb.log.info("PASS")
                passed += 1
            else:
                raise TestFailure(f"Result mismatch: expected {expected}, got {result}")
                
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
        
        # Reset between tests
        await reset_dut(dut)
    
    # Report
    cocotb.log.info(f"\n{'='*50}")
    cocotb.log.info(f"Total: {len(test_cases)}, Passed: {passed}, Failed: {failed}")
    cocotb.log.info(f"{'='*50}")
    
    if failed > 0:
        raise TestFailure(f"{failed} test(s) failed")
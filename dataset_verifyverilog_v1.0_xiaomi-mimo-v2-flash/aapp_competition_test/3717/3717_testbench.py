import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helpers
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
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

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

def float_to_fixed(f, frac=16):
    return int(f * (1 << frac))

def fixed_to_float(v, frac=16):
    return v / (1 << frac)

def scale_coord(coord, scale=1000):
    """Scale coordinate by factor to fit in 16-bit signed"""
    return int(coord * scale)

def unscale_coord(scaled, scale=1000):
    """Unscale back to original"""
    return scaled / scale

# Main test function
@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_rectangle_point(dut):
    CLK_NS = 10
    MAX_CYCLES = 300
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        # n=3, simple
        (3, [
            (0, 0, 1000, 1000),  # (0,0)-(1,1) scaled
            (1000, 1000, 2000, 2000),  # (1,1)-(2,2)
            (3000, 0, 4000, 1000),  # (3,0)-(4,1)
        ], (1000, 1000)),  # Expected: (1,1) scaled
        
        # n=4, example from prompt
        (4, [
            (0, 0, 5000, 5000),  # (0,0)-(5,5)
            (0, 0, 4000, 4000),  # (0,0)-(4,4)
            (1000, 1000, 4000, 4000),  # (1,1)-(4,4)
            (1000, 1000, 4000, 4000),  # (1,1)-(4,4)
        ], (1000, 1000)),  # Expected: (1,1)
        
        # n=5, from example
        (5, [
            (0, 0, 10000, 8000),  # (0,0)-(10,8)
            (1000, 2000, 6000, 7000),  # (1,2)-(6,7)
            (2000, 3000, 5000, 6000),  # (2,3)-(5,6)
            (3000, 4000, 4000, 5000),  # (3,4)-(4,5)
            (8000, 1000, 9000, 2000),  # (8,1)-(9,2)
        ], (3000, 4000)),  # Expected: (3,4)
        
        # n=2, edge case
        (2, [
            (-1000, -1000, 0, 0),  # (-1,-1)-(0,0)
            (0, 0, 1000, 1000),  # (0,0)-(1,1)
        ], (0, 0)),  # Expected: (0,0)
    ]
    
    for tc_idx, (n, rectangles, expected) in enumerate(test_cases):
        cocotb.log.info(f"\nTest case {tc_idx + 1}: n={n}")
        
        # Set n
        if has_signal(dut, 'n'):
            dut.n.value = n
        
        # Write rectangles to arrays
        for i in range(n):
            x1, y1, x2, y2 = rectangles[i]
            
            # Scale coordinates to fit 16-bit signed
            x1_scaled = scale_coord(x1, 1)
            y1_scaled = scale_coord(y1, 1)
            x2_scaled = scale_coord(x2, 1)
            y2_scaled = scale_coord(y2, 1)
            
            # Clamp to 16-bit signed range
            def clamp_signed(val):
                if val < -(1 << 15):
                    return -(1 << 15)
                elif val >= (1 << 15):
                    return (1 << 15) - 1
                return val
            
            x1_scaled = clamp_signed(x1_scaled)
            y1_scaled = clamp_signed(y1_scaled)
            x2_scaled = clamp_signed(x2_scaled)
            y2_scaled = clamp_signed(y2_scaled)
            
            # Write to signals
            if has_signal(dut, f'rect_x1'):
                dut.rect_x1[i].value = x1_scaled
                dut.rect_y1[i].value = y1_scaled
                dut.rect_x2[i].value = x2_scaled
                dut.rect_y2[i].value = y2_scaled
            else:
                # Individual signals
                for field in ['x1', 'y1', 'x2', 'y2']:
                    sig_name = f'rect_{field}'
                    if has_signal(dut, sig_name):
                        arr = getattr(dut, sig_name)
                        if hasattr(arr, '__getitem__'):
                            arr[i].value = locals()[f'{field}_scaled']
            
            cocotb.log.info(f"  Rectangle {i}: ({x1},{y1},{x2},{y2}) scaled to ({x1_scaled},{y1_scaled},{x2_scaled},{y2_scaled})")
        
        # Start computation
        if has_signal(dut, 'start'):
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
        else:
            await RisingEdge(dut.clk)
        
        # Wait for done
        done = False
        for cycle in range(MAX_CYCLES):
            await RisingEdge(dut.clk)
            if has_signal(dut, 'done') and is_value_defined(dut.done.value):
                if int(dut.done.value) == 1:
                    done = True
                    break
        
        if not done:
            raise TestFailure(f"Timeout after {MAX_CYCLES} cycles")
        
        # Read result
        if not has_signal(dut, 'result_x') or not has_signal(dut, 'result_y'):
            # Try packed result
            if has_signal(dut, 'result'):
                result = int(dut.result.value)
                result_x = to_signed(result & 0xFFFF, 16)
                result_y = to_signed((result >> 16) & 0xFFFF, 16)
            else:
                raise TestFailure("Result signals not found")
        else:
            result_x = to_signed(int(dut.result_x.value), 16)
            result_y = to_signed(int(dut.result_y.value), 16)
        
        # Unscale
        result_x_unscaled = result_x
        result_y_unscaled = result_y
        
        # Check against expected (allow small tolerance)
        exp_x, exp_y = expected
        
        cocotb.log.info(f"Result: ({result_x_unscaled}, {result_y_unscaled})")
        cocotb.log.info(f"Expected: ({exp_x}, {exp_y})")
        
        if result_x_unscaled != exp_x or result_y_unscaled != exp_y:
            raise TestFailure(f"Test {tc_idx + 1} failed: Expected ({exp_x}, {exp_y}), got ({result_x_unscaled}, {result_y_unscaled})")
    
    cocotb.log.info(f"All {len(test_cases)} test cases passed!")

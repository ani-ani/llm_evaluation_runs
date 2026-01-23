import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# Configuration
N = 8
WIDTH = 8

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

def clamp_to_width_signed(value, bits):
    min_val = -(1 << (bits-1))
    max_val = (1 << (bits-1)) - 1
    if value < min_val:
        return min_val
    if value > max_val:
        return max_val
    return value

# Main test
@cocotb.test(timeout_time=1000, timeout_unit='ms')
async def test_rectangle_intersect(dut):
    dut._log.info(f'Testing with N={N}, WIDTH={WIDTH}')
    
    test_cases = [
        ([(0,0,2,2), (1,1,3,4), (5,7,6,8)], 1, 'Example 1: two intersect'),
        ([(0,0,20,20), (1,1,3,4), (2,10,9,12), (11,3,19,18)], 0, 'Example 2: no intersections'),
        ([(0,0,10,10), (2,2,8,8)], 0, 'Containment: no intersection'),
        ([(0,0,5,5), (3,3,8,8)], 1, 'Crossing: intersect'),
        ([(0,0,2,2), (2,2,4,4)], 0, 'Corner touch: distinct coordinates'),
    ]
    
    for idx, (rects, expected, description) in enumerate(test_cases):
        dut._log.info(f'\nTest {idx+1}: {description}')
        
        for i in range(N):
            if i < len(rects):
                x1, y1, x2, y2 = rects[i]
            else:
                base = -128 + i * 2
                x1, y1, x2, y2 = base, base, base+1, base+1
            
            x1 = clamp_to_width_signed(x1, WIDTH)
            y1 = clamp_to_width_signed(y1, WIDTH)
            x2 = clamp_to_width_signed(x2, WIDTH)
            y2 = clamp_to_width_signed(y2, WIDTH)
            
            for coord, val in zip(['x1','y1','x2','y2'], [x1,y1,x2,y2]):
                sig_name = f'{coord}_{i}'
                val_unsigned = from_signed(val, WIDTH)
                getattr(dut, sig_name).value = val_unsigned
        
        await Timer(10, units='ns')
        
        if not is_value_defined(dut.intersect.value):
            raise TestFailure(f'Test {idx+1}: intersect output undefined')
        
        result = int(dut.intersect.value)
        if result != expected:
            raise TestFailure(f'Test {idx+1}: expected {expected}, got {result}')
        
        dut._log.info(f'  PASS: intersect = {result}')
    
    dut._log.info('\nAll tests passed!')
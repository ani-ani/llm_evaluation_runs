import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

# Helpers
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

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def float_to_fixed(f, frac=8):
    return int(f * (1 << frac))

def fixed_to_float(v, frac=8):
    return v / (1 << frac)

# Scaling constants
COORD_SCALE = 100  # Scale x,y,h by 100
LENGTH_SCALE = 1000  # Scale lengths by 1000
MAX_COORD = 1000000
MAX_HEIGHT = 1000000

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

def calc_distance(x1, y1, x2, y2):
    """Calculate Euclidean distance, scaled appropriately"""
    dx = (x2 - x1) * COORD_SCALE
    dy = (y2 - y1) * COORD_SCALE
    dist = math.sqrt(dx*dx + dy*dy)
    return int(dist * LENGTH_SCALE)

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_aqueduct(dut):
    # Check if sequential
    is_seq = has_signal(dut, 'clk')
    
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    
    # Test case 1: Valid matching
    # Springs at hills 3,4 (indices 2,3) -> springs: [2,3]
    # Towns at hills 1,5 (indices 0,4) -> towns: [0,4]
    # Hills: [0,0,6], [3,4,7], [0,8,8], [6,8,8], [6,0,6], [6,4,8]
    # Spring 0 (hill 2): x=0,y=8,h=8
    # Spring 1 (hill 3): x=6,y=8,h=8
    # Town 0 (hill 0): x=0,y=0,h=6
    # Town 1 (hill 4): x=6,y=0,h=6
    # Heights valid: 8>6
    # Distances: 
    # Spring0 to Town0: dist = sqrt(0^2 + 8^2) = 8
    # Spring0 to Town1: dist = sqrt(6^2 + 8^2) = 10
    # Spring1 to Town0: dist = sqrt(6^2 + 8^2) = 10
    # Spring1 to Town1: dist = sqrt(0^2 + 8^2) = 8
    # Optimal: Spring0-Town0 (8) + Spring1-Town1 (8) = 16
    # Scaled: 16 * 1000 = 16000
    
    # Setup data
    hill_coords = [
        (0, 0, 6),
        (3, 4, 7),
        (0, 8, 8),
        (6, 8, 8),
        (6, 0, 6),
        (6, 4, 8)
    ]
    
    springs = [2, 3]  # hill indices (1-based in input, 0-based here)
    towns = [0, 4]
    
    # Scale and set hill data
    for i, (x, y, h) in enumerate(hill_coords):
        if i < 16:  # Max 16 hills
            # Scale values
            x_scaled = int(x * COORD_SCALE)
            y_scaled = int(y * COORD_SCALE)
            h_scaled = int(h * COORD_SCALE)
            
            # Clamp to 8 bits (assuming Q8.0 or similar)
            x_scaled = clamp_to_width(x_scaled, 8)
            y_scaled = clamp_to_width(y_scaled, 8)
            h_scaled = clamp_to_width(h_scaled, 8)
            
            # Assign to arrays (if individual signals)
            if has_signal(dut, f'hill_x_{i}'):
                getattr(dut, f'hill_x_{i}').value = x_scaled
                getattr(dut, f'hill_y_{i}').value = y_scaled
                getattr(dut, f'hill_h_{i}').value = h_scaled
            else:
                # Packed array approach
                dut.hill_x.value = (dut.hill_x.value or 0) | (x_scaled << (i*8))
                dut.hill_y.value = (dut.hill_y.value or 0) | (y_scaled << (i*8))
                dut.hill_h.value = (dut.hill_h.value or 0) | (h_scaled << (i*8))
    
    # Set springs and towns (packed 4-bit each for 16 items)
    springs_packed = 0
    for i, s_idx in enumerate(springs):
        springs_packed |= (s_idx & 0xF) << (i*4)
    
    towns_packed = 0
    for i, t_idx in enumerate(towns):
        towns_packed |= (t_idx & 0xF) << (i*4)
    
    dut.springs.value = springs_packed
    dut.towns.value = towns_packed
    
    # Max length (scaled, assume 8.0 format)
    max_len = int(8 * LENGTH_SCALE)  # q=8 from input
    dut.max_len.value = clamp_to_width(max_len, 8)
    
    if is_seq:
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 0
        while timeout < 2000:
            await RisingEdge(dut.clk)
            timeout += 1
            if has_signal(dut, 'done') and is_value_defined(dut.done.value):
                if int(dut.done.value) == 1:
                    break
        else:
            raise TestFailure("Timeout waiting for done")
    else:
        await Timer(100, units='ns')
    
    # Check result
    if has_signal(dut, 'impossible') and is_value_defined(dut.impossible.value):
        if int(dut.impossible.value) == 1:
            cocotb.log.info("Result: IMPOSSIBLE")
            # This test should succeed (match found), so impossible should be 0
            raise TestFailure("Expected possible solution but got IMPOSSIBLE")
    
    if not is_value_defined(dut.result.value):
        raise TestFailure("Result undefined")
    
    result = int(dut.result.value)
    cocotb.log.info(f"Result value: {result}")
    
    # Expected: optimal matching is 8+8 = 16 units (unscaled)
    # Scaled: 16 * 1000 = 16000
    expected = 16000
    
    # Allow some tolerance for fixed-point approximations
    if abs(result - expected) > 100:
        raise TestFailure(f"Expected ~{expected}, got {result}")
    
    cocotb.log.info(f"Test 1 passed: {result}")
    
    # Test case 2: Impossible case
    # Springs: [1,3] (hills 1,3)
    # Towns: [2,4] (hills 2,4)
    # Need to check heights
    # Spring 1: hill 1 -> (3,4,7)
    # Spring 3: hill 3 -> (6,8,8)
    # Town 2: hill 2 -> (0,8,8)  <-- Same height as spring 3, invalid
    # Town 4: hill 4 -> (6,0,6)  <-- Spring heights valid
    
    # Reset
    await reset_dut(dut)
    
    springs2 = [1, 3]
    towns2 = [2, 4]
    
    springs_packed2 = 0
    for i, s_idx in enumerate(springs2):
        springs_packed2 |= (s_idx & 0xF) << (i*4)
    
    towns_packed2 = 0
    for i, t_idx in enumerate(towns2):
        towns_packed2 |= (t_idx & 0xF) << (i*4)
    
    dut.springs.value = springs_packed2
    dut.towns.value = towns_packed2
    
    max_len2 = int(3 * LENGTH_SCALE)
    dut.max_len.value = clamp_to_width(max_len2, 8)
    
    if is_seq:
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        timeout = 0
        while timeout < 2000:
            await RisingEdge(dut.clk)
            timeout += 1
            if has_signal(dut, 'done') and is_value_defined(dut.done.value):
                if int(dut.done.value) == 1:
                    break
        else:
            raise TestFailure("Timeout waiting for done")
    else:
        await Timer(100, units='ns')
    
    # Check impossible flag
    if has_signal(dut, 'impossible') and is_value_defined(dut.impossible.value):
        if int(dut.impossible.value) == 1:
            cocotb.log.info("Test 2 passed: IMPOSSIBLE correctly detected")
        else:
            raise TestFailure("Expected IMPOSSIBLE but got a result")
    else:
        # If no impossible flag, check if result is some sentinel
        if is_value_defined(dut.result.value):
            result2 = int(dut.result.value)
            if result2 == 0 or result2 == (1 << 24) - 1:
                cocotb.log.info("Test 2 passed: IMPOSSIBLE detected via result")
            else:
                raise TestFailure(f"Expected IMPOSSIBLE but got {result2}")
    
    cocotb.log.info("All tests passed!")
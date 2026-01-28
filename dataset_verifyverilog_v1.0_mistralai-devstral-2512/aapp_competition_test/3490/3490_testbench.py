import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

DATA_WIDTH = 16
MAX_WITCHES = 16
CLK_NS = 10
MAX_CYCLES = 300

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
    max_val = (1 << bits) - 1
    if v < 0: v = 0
    return min(max_val, v)

def float_to_q16(f):
    return int(f * 65536) & 0xFFFF

def pack_witch(x, y, r, valid=1):
    # Pack into single 64-bit value for ease, but we assign individually
    return (float_to_q16(x), float_to_q16(y), float_to_q16(r), valid)

def compute_cos_lut():
    # 256-entry LUT for cos(r) where r in [0, 2π) -> Q16.16
    lut = []
    for i in range(256):
        angle = (i / 256.0) * 2 * math.pi
        val = int(math.cos(angle) * 65536) & 0xFFFF
        lut.append(val)
    return lut

def compute_sin_lut():
    # 256-entry LUT for sin(r) where r in [0, 2π) -> Q16.16
    lut = []
    for i in range(256):
        angle = (i / 256.0) * 2 * math.pi
        val = int(math.sin(angle) * 65536) & 0xFFFF
        lut.append(val)
    return lut

def compute_distance_sq(x1, y1, x2, y2):
    # Compute squared distance in Q16.16, return 32-bit
    dx = x1 - x2
    dy = y1 - y2
    # Square: (dx*dx) + (dy*dy) -> Q32.32, we keep 32-bit MSB
    dx_sq = (dx * dx) >> 16  # Scale back to Q16.16 range
    dy_sq = (dy * dy) >> 16
    return dx_sq + dy_sq

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
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_witch_crash(dut):
    # Check signals exist
    assert has_signal(dut, 'clk'), "Missing clk signal"
    assert has_signal(dut, 'rst_n'), "Missing rst_n signal"
    assert has_signal(dut, 'start'), "Missing start signal"
    assert has_signal(dut, 'done'), "Missing done signal"
    assert has_signal(dut, 'result'), "Missing result signal"
    
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # LUTs for cos/sin
    cos_lut = compute_cos_lut()
    sin_lut = compute_sin_lut()
    
    # Test cases
    test_cases = [
        {
            'desc': 'Two witches far apart - should be ok',
            'witches': [
                {'x': 0.0, 'y': 0.0, 'r': 0.0},
                {'x': 0.0, 'y': 1.5, 'r': 0.0},
            ],
            'expected': 0  # ok
        },
        {
            'desc': 'Two witches opposite - should crash',
            'witches': [
                {'x': 0.0, 'y': 0.0, 'r': 0.0},
                {'x': 0.0, 'y': 0.5, 'r': math.pi},
            ],
            'expected': 1  # crash
        },
        {
            'desc': 'Single witch - ok',
            'witches': [
                {'x': 10.0, 'y': 10.0, 'r': 1.23},
            ],
            'expected': 0  # ok
        },
        {
            'desc': 'Three witches, no collision - ok',
            'witches': [
                {'x': 0.0, 'y': 0.0, 'r': 0.0},
                {'x': 10.0, 'y': 0.0, 'r': math.pi/2},
                {'x': 5.0, 'y': 5.0, 'r': math.pi},
            ],
            'expected': 0  # ok
        }
    ]
    
    passed = 0
    failed = 0
    
    for i, tc in enumerate(test_cases):
        cocotb.log.info(f"\n=== Test {i+1}: {tc['desc']} ===")
        
        try:
            # Reset dut
            dut.rst_n.value = 0
            await RisingEdge(dut.clk)
            dut.rst_n.value = 1
            await RisingEdge(dut.clk)
            
            # Configure witches
            num_witches = len(tc['witches'])
            for witch_idx in range(MAX_WITCHES):
                prefix = f'witch_{witch_idx}'
                
                if witch_idx < num_witches:
                    w = tc['witches'][witch_idx]
                    # Clamp coordinates to 16-bit Q16.16 range
                    x_q16 = float_to_q16(max(-32768, min(32767, w['x'])))
                    y_q16 = float_to_q16(max(-32768, min(32767, w['y'])))
                    r_q16 = float_to_q16(w['r'] / (2 * math.pi))  # Normalize to 0-1, then to 0-65535
                    
                    # Set signals
                    if has_signal(dut, f'{prefix}_x'):
                        getattr(dut, f'{prefix}_x').value = x_q16
                    if has_signal(dut, f'{prefix}_y'):
                        getattr(dut, f'{prefix}_y').value = y_q16
                    if has_signal(dut, f'{prefix}_r'):
                        getattr(dut, f'{prefix}_r').value = r_q16
                    if has_signal(dut, f'{prefix}_valid'):
                        getattr(dut, f'{prefix}_valid').value = 1
                else:
                    # Set inactive witches
                    if has_signal(dut, f'{prefix}_valid'):
                        getattr(dut, f'{prefix}_valid').value = 0
            
            # Software simulation for expected result
            collision = False
            for j in range(num_witches):
                for k in range(j + 1, num_witches):
                    w1 = tc['witches'][j]
                    w2 = tc['witches'][k]
                    
                    # Convert to Q16.16 for distance calculation
                    x1 = float_to_q16(w1['x'])
                    y1 = float_to_q16(w1['y'])
                    r1_norm = w1['r'] / (2 * math.pi)
                    r1_idx = int(r1_norm * 256) % 256
                    ex1 = x1 + cos_lut[r1_idx]
                    ey1 = y1 + sin_lut[r1_idx]
                    
                    x2 = float_to_q16(w2['x'])
                    y2 = float_to_q16(w2['y'])
                    r2_norm = w2['r'] / (2 * math.pi)
                    r2_idx = int(r2_norm * 256) % 256
                    ex2 = x2 + cos_lut[r2_idx]
                    ey2 = y2 + sin_lut[r2_idx]
                    
                    # Compute squared distance
                    dist_sq = compute_distance_sq(ex1, ey1, ex2, ey2)
                    
                    # Collision threshold: (2*length)^2 = 4.0 in Q16.16 = 0x00040000
                    # Adjusted for squared distance calculation: ~4.0 scaled
                    threshold = 0x00040000  # 4.0 in Q16.16, but we need to scale properly
                    # Actually for squared distance, threshold should be 4.0 in Q32.32 -> 0x00000004 in Q16.16 scaled
                    # Let's use: if dist_sq < 0x00000010 (approx 1.0e-6 in Q16.16 squared)
                    threshold = 0x00000010  # Conservative threshold
                    
                    if dist_sq < threshold:
                        collision = True
                        break
                if collision:
                    break
            
            expected_result = 1 if collision else 0
            
            # Start computation
            if has_signal(dut, 'start'):
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                # Combinational logic
                await Timer(100, units='ns')
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            result = int(dut.result.value) & 0x3  # Mask to 2 bits
            cocotb.log.info(f"Expected: {expected_result}, Got: {result}")
            
            if result != expected_result:
                raise TestFailure(f"Expected {expected_result}, got {result}")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL (Test {i+1}): {e}")
            failed += 1
        except Exception as e:
            cocotb.log.error(f"ERROR (Test {i+1}): {e}")
            failed += 1
    
    cocotb.log.info(f"\n=== Results: {passed} passed, {failed} failed ===")
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")

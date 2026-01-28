import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

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

def float_to_fixed(f, frac=16):
    return int(f * (1 << frac))

def fixed_to_float(v, frac=16):
    return v / (1 << frac)

def scaled_float_to_q88(f):
    # Map -1000000..1000000 to -128..128, then to Q8.8
    scaled = f / 1000000.0 * 128.0
    return int(scaled * 256.0)  # Q8.8 = value * 256

def coord_to_q88(coord):
    # coord is integer -1000000 to 1000000
    # Map to Q8.8: range -128.0 to 127.996
    scaled = (coord / 1000000.0) * 128.0
    return int(scaled * 256.0)

DATA_WIDTH = 16
MAX_SEGMENTS = 16
CLK_NS = 10
MAX_CYCLES = 10000

def write_segment(dut, idx, x0, y0, x1, y1):
    dut.seg_ptr.value = idx
    dut.seg_x0.value = coord_to_q88(x0) & 0xFFFF
    dut.seg_y0.value = coord_to_q88(y0) & 0xFFFF
    dut.seg_x1.value = coord_to_q88(x1) & 0xFFFF
    dut.seg_y1.value = coord_to_q88(y1) & 0xFFFF
    dut.seg_valid.value = 1

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_line_intersections(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        dut.rst_n.value = 0
        if has_signal(dut, 'start'): dut.start.value = 0
        if has_signal(dut, 'seg_valid'): dut.seg_valid.value = 0
        for _ in range(3): await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    test_cases = [
        # Sample 1: 3 intersections
        ([ (1,3,9,5), (2,2,6,8), (4,8,9,3) ], 3, "Three segments intersect at 3 points"),
        # Sample 2: 1 intersection (concurrent at single point)
        ([ (5,2,7,10), (7,4,4,10), (2,4,10,8) ], 1, "All three intersect at one point"),
        # Sample 3: 1 intersection
        ([ (2,1,6,5), (2,5,5,4), (5,1,7,7) ], 1, "One intersection point"),
        # Sample 4: vertical segments share endpoint
        ([ (-1,-2,-1,-1), (-1,2,-1,-1) ], 1, "Share endpoint at (-1,-1)"),
        # Sample 5: overlapping lines (infinite intersections)
        ([ (0,0,2,2), (1,1,-5,-5) ], 0xFFFF, "Overlapping segments (infinite)"),
        # Additional: parallel non-intersecting
        ([ (0,0,5,5), (0,1,5,6) ], 0, "Parallel lines, no intersection"),
    ]
    
    for i, (segments, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        
        # Reset
        if is_seq:
            dut.rst_n.value = 0
            await RisingEdge(dut.clk)
            dut.rst_n.value = 1
            await RisingEdge(dut.clk)
        
        # Load segments
        if is_seq:
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            await RisingEdge(dut.clk)
            
            for idx, seg in enumerate(segments):
                x0, y0, x1, y1 = seg
                write_segment(dut, idx, x0, y0, x1, y1)
                await RisingEdge(dut.clk)
            dut.seg_valid.value = 0
        else:
            # Combinational: assign all at once
            for idx, seg in enumerate(segments):
                x0, y0, x1, y1 = seg
                if has_signal(dut, f'seg_x0_{idx}'):
                    setattr(dut, f'seg_x0_{idx}', coord_to_q88(x0))
                    setattr(dut, f'seg_y0_{idx}', coord_to_q88(y0))
                    setattr(dut, f'seg_x1_{idx}', coord_to_q88(x1))
                    setattr(dut, f'seg_y1_{idx}', coord_to_q88(y1))
            await Timer(100, units='ns')
        
        # Wait for computation
        if is_seq:
            max_cycles = MAX_CYCLES if expected != 0xFFFF else 5000
            for _ in range(max_cycles):
                await RisingEdge(dut.clk)
                if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                    break
        else:
            await Timer(200, units='ns')
        
        # Check result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Test {i+1}: Result undefined")
        
        result = int(dut.result.value)
        if result == 0xFFFF:
            result_str = "infinite"
        else:
            result_str = str(result)
        
        if expected == 0xFFFF:
            if result != 0xFFFF:
                raise TestFailure(f"Test {i+1}: Expected infinite (-1), got {result_str}")
        else:
            if result != expected:
                raise TestFailure(f"Test {i+1}: Expected {expected}, got {result_str} - {desc}")
        
        cocotb.log.info(f"  PASS: {result_str}")

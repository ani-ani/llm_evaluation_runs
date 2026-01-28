import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

# Helpers
DATA_WIDTH, ARRAY_SIZE, CLK_NS, MAX_CYCLES = 16, 16, 10, 10000

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
    if has_signal(dut, 'n_inputs_ready'): dut.n_inputs_ready.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# Helper to compute distance squared (scaled for fixed-point)
def compute_dist_sq(x1, y1, x2, y2, scale_bits=8):
    dx = x2 - x1
    dy = y2 - y1
    # Use 32-bit to avoid overflow
    return dx*dx + dy*dy

# Helper to compute tunnel length (squared for comparison)
def compute_tunnel_len_sq(island1, island2):
    # island is (x, y, r) scaled Q8.8
    dx = island2[0] - island1[0]
    dy = island2[1] - island1[1]
    dist_sq = dx*dx + dy*dy
    r_sum = island1[2] + island2[2]
    r_sum_sq = r_sum * r_sum
    # Tunnel length squared = dist_sq - r_sum_sq, but only if dist > r_sum
    # However, we need actual length for output, but for sorting we can use squared
    # But output requires actual length. Let's compute actual length in cm (scaled by 100? No, integers)
    # Input is cm, output cm. We use integers.
    # For comparison in HDL, we'll use squared distances.
    # In testbench, we compute real distance.
    # Tunnel length is max(0, sqrt(dist_sq) - r_sum)
    import math
    dist = math.sqrt(dist_sq / (1 << 16)) # scale back from Q16.16? No, we used Q8.8 for coord, but dist is in cm.
    # Let's assume input is integer cm. We scale to Q8.8 for HDL, but testbench uses integers.
    # Re-read: Input in cm. HDL uses 16-bit. Max 10^6 cm, so Q8.8 is not enough. Q16.16? Too big.
    # Let's use 16-bit integer for coordinates (max 10^6 fits in 16-bit signed? 2^15-1=32767, NO).
    # Adjust: Use 32-bit in HDL for intermediate. But spec says 16-bit arrays. Scale down input.
    # For testbench, we use integers but clamp to 16-bit range for HDL assignment.
    # Recalculate: HDL uses 16-bit for coordinates. Max 10^6 > 65535. So scale down by factor 100 or 1000.
    # In testbench, we divide coordinates by 100 to fit 16-bit.
    # Distance calculation in HDL uses integer math.
    pass

# Revised scaling: Coordinates divided by 10 to fit 10^5 into 16-bit (0-65535).
# Radii and heights are smaller, fit in 16-bit.
# In testbench, we divide coordinates by 10.

def scale_coord(v): return v // 10

def unscale_len(v): return v * 10  # Scale back up

@cocotb.test(timeout_time=10, timeout_unit="s")
async def test_min_tunnel(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test case 1: 3 islands, 2 palms, k=3 -> output 1400
    # Input: (0,0,400), (1000,0,400), (2000,0,400)
    # Palms: (300,0,150), (1300,0,150)
    # Scaled: Divide coords by 10 -> (0,0,400), (100,0,400), (200,0,400)
    # Palms: (30,0,150), (130,0,150)
    islands_1 = [(0, 0, 400), (100, 0, 400), (200, 0, 400)]
    palms_1 = [(30, 0, 150), (130, 0, 150)]
    k_1 = 3
    
    # Test case 2: k=2 -> impossible
    palms_2 = [(30, 0, 100), (130, 0, 100)] # heights scaled? Input 100, scaled 100.
    k_2 = 2
    
    test_cases = [
        (islands_1, palms_1, k_1, 1400, "Sample 1"),
        (islands_1, palms_2, k_2, 0xFFFF, "Sample 2 Impossible")
    ]
    
    for t_idx, (islands, palms, k, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {t_idx+1}: {desc}")
        try:
            n_islands = len(islands)
            n_palms = len(palms)
            
            # Write inputs
            if has_signal(dut, 'n_islands'):
                dut.n_islands.value = n_islands
            if has_signal(dut, 'n_palms'):
                dut.n_palms.value = n_palms
            if has_signal(dut, 'k'):
                dut.k.value = k
            
            # Write islands
            for i in range(n_islands):
                x, y, r = islands[i]
                # Clamp to 16-bit
                dut.island_x[i].value = clamp_to_width(x, 16)
                dut.island_y[i].value = clamp_to_width(y, 16)
                dut.island_r[i].value = clamp_to_width(r, 16)
            
            # Write palms
            for i in range(n_palms):
                x, y, h = palms[i]
                dut.palm_x[i].value = clamp_to_width(x, 16)
                dut.palm_y[i].value = clamp_to_width(y, 16)
                dut.palm_h[i].value = clamp_to_width(h, 16)
            
            # Start
            if is_seq:
                dut.start.value = 1
                if has_signal(dut, 'n_inputs_ready'):
                    dut.n_inputs_ready.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                if has_signal(dut, 'n_inputs_ready'):
                    dut.n_inputs_ready.value = 0
                await wait_for_done(dut)
            else:
                await Timer(100, units='ns')
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            
            # Check result
            if result == 0xFFFF:
                if expected != 0xFFFF:
                    raise TestFailure(f"Expected {expected}, got impossible (0xFFFF)")
            else:
                # Scale back
                actual_result = unscale_len(result)
                if actual_result != expected:
                    raise TestFailure(f"Expected {expected}, got {actual_result}")
            
            cocotb.log.info(f"PASS: Result {result}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL {desc}: {e}")
            raise

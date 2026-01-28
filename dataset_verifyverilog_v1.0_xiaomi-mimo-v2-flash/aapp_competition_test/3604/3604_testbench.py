import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

DATA_WIDTH, ARRAY_SIZE, CLK_NS, MAX_CYCLES = 16, 8, 10, 256

# Helpers from template
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

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def write_coords(dut, coords):
    """Write coordinates to Q8.8 fixed-point inputs"""
    for i, (x, y) in enumerate(coords):
        x_fixed = int(x * 256)  # Q8.8
        y_fixed = int(y * 256)
        dut.sensor_x[i].value = clamp_to_width(x_fixed, DATA_WIDTH)
        dut.sensor_y[i].value = clamp_to_width(y_fixed, DATA_WIDTH)
    # Pad remaining sensors with 0
    for i in range(len(coords), ARRAY_SIZE):
        dut.sensor_x[i].value = 0
        dut.sensor_y[i].value = 0

@cocotb.test(timeout_time=10, timeout_unit="ms")
async def test_sensor_clique(dut):
    if not has_signal(dut, 'clk'):
        await Timer(100, units='ns')
        return
    
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases: (coords, d, expected_size, expected_indices_set, desc)
    test_cases = [
        ([(0,0), (0,1), (1,0), (1,1)], 1.0, 2, {0,1}, "Square, d=1.0"),
        ([(0,0), (0,2), (100,100), (100,110), (100,120)], 20.0, 3, {2,3,4}, "Cluster at (100,100)"),
        ([(0,0), (0,10)], 15.0, 2, {0,1}, "Two points in range"),
        ([(0,0), (0,10), (20,0)], 5.0, 1, {0}, "Single point max"),
    ]
    
    passed = failed = 0
    
    for i, (coords, d, exp_size, exp_set, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Write inputs
            await write_coords(dut, coords)
            dut.sensor_n.value = len(coords)
            d_fixed = int(d * 256)  # Q8.8
            dut.d_threshold.value = clamp_to_width(d_fixed, DATA_WIDTH)
            
            # Start
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut, MAX_CYCLES)
            
            # Read outputs
            size = int(dut.size.value)
            indices_packed = int(dut.indices.value)
            
            # Decode packed indices
            indices = []
            for bit in range(4 * ARRAY_SIZE):
                if (indices_packed >> bit) & 1:
                    idx = bit // 4
                    if idx < size:
                        indices.append(idx + 1)  # 1-based
            
            # Verify
            if size != exp_size:
                raise TestFailure(f"Expected size {exp_size}, got {size}")
            
            if size > 0:
                found_set = set(i - 1 for i in indices)  # Back to 0-based
                if found_set != exp_set:
                    raise TestFailure(f"Expected indices {exp_set}, got {found_set}")
            
            # Validate clique property
            if size > 1:
                # Check all pairs within distance
                d_sq = d * d
                for a in range(size):
                    for b in range(a + 1, size):
                        idx_a = indices[a] - 1
                        idx_b = indices[b] - 1
                        x1, y1 = coords[idx_a]
                        x2, y2 = coords[idx_b]
                        dist_sq = (x1 - x2) ** 2 + (y1 - y2) ** 2
                        if dist_sq > d_sq + 1e-9:
                            raise TestFailure(f"Pair ({idx_a+1},{idx_b+1}) distance {math.sqrt(dist_sq):.2f} > {d}")
            
            cocotb.log.info(f"  Result: size={size}, indices={indices}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed")
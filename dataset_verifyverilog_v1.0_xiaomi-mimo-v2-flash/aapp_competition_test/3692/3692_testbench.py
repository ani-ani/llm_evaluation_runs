import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helpers

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

# Testbench Constants
DATA_WIDTH = 8 # Q4.4 fixed point
CLK_NS = 10
MAX_CYCLES = 200

def encode_circle(x, y, r):
    # Inputs are int (-10 to 10 for x,y, 1-10 for r)
    # Convert to Q4.4 fixed point: value * 16
    qx = (x << 4) & 0xFF
    qy = (y << 4) & 0xFF
    qr = (r << 4) & 0xFF
    return qx, qy, qr

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=100):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_circle_regions(dut):
    # Start Clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)

    # Test Cases: (n, [(x,y,r)...], expected_result)
    test_cases = [
        (1, [(0,0,10)], 2),
        (2, [(0,0,2), (3,0,2)], 4), # Intersecting
        (2, [(0,0,1), (10,10,1)], 3), # Disjoint
        (3, [(0,0,1), (2,0,1), (4,0,1)], 4),
        (3, [(0,0,2), (3,0,2), (6,0,2)], 6),
        (3, [(0,0,2), (2,0,2), (1,1,2)], 8),
        (3, [(0,0,1), (0,3,2), (4,0,3)], 7), # From dataset
        (3, [(0,0,5), (1,7,5), (7,7,5)], 7), # From dataset
    ]

    passed = 0
    failed = 0

    for i, (n, circles, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: n={n}, circles={circles}, expected={expected}")
        
        # Set N
        dut.n.value = n
        
        # Set Circles (Individual Assignment)
        # Note: The spec says arrays, so we iterate 0 to 2 (max)
        # For inactive circles, values don't strictly matter, but we set them to 0
        
        for idx in range(3):
            if idx < len(circles):
                x, y, r = circles[idx]
                qx, qy, qr = encode_circle(x, y, r)
            else:
                qx, qy, qr = 0, 0, 0
            
            # Access ports: circ_x[0], circ_x[1]... or circ_x[0:2]
            # Assuming packed arrays or individual signals. 
            # Common pattern: dut.circ_x[0].value = val
            
            try:
                dut.circ_x[idx].value = clamp_to_width(qx, DATA_WIDTH)
                dut.circ_y[idx].value = clamp_to_width(qy, DATA_WIDTH)
                dut.circ_r[idx].value = clamp_to_width(qr, DATA_WIDTH)
            except AttributeError:
                # Fallback for flat naming: circ_x_0, circ_x_1...
                getattr(dut, f'circ_x_{idx}').value = clamp_to_width(qx, DATA_WIDTH)
                getattr(dut, f'circ_y_{idx}').value = clamp_to_width(qy, DATA_WIDTH)
                getattr(dut, f'circ_r_{idx}').value = clamp_to_width(qr, DATA_WIDTH)

        # Trigger
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait
        await wait_for_done(dut, max_cycles=50)
        
        # Check Result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Result undefined for test {i+1}")
            
        result = int(dut.result.value)
        if result != expected:
            cocotb.log.error(f"FAIL Test {i+1}: Expected {expected}, got {result}")
            failed += 1
        else:
            cocotb.log.info(f"PASS Test {i+1}: {result}")
            passed += 1

    if failed > 0:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")
    
    cocotb.log.info(f"All tests passed! ({passed}/{passed + failed})")

import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helpers
def is_value_defined(v):
    try: int(v); return True
    except: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, int(v)))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except: return False

# Fixed-point helpers (Q16.16)
def float_to_fixed(f, frac=16):
    return int(f * (1 << frac))

def fixed_to_float(v, frac=16):
    return v / (1 << frac)

# Scale input 0-100 to Q16.16 (multiply by 256 to shift to Q16.0 then to Q16.16? No)
# Input is 0-100, max 100. Scale factor 2.56 to fit 8-bit? Actually input is 8-bit 0-100.
# To Q16.16: val * 256 * 256? No, 8-bit integer to Q16.16: val << 16.
# Wait, input range 0-100. We want fixed point with 16 fractional bits.
# So a_fp = a_in << 16 (approx 0-100*65536 = 6.5M fits in 23 bits).
# But spec says 8-bit scaled input. So we interpret a_in as 0-100.
# a_fp = a_in * 256 (Q8.0). Then convert to Q16.16: a_fp << 8? No.
# Let's define: a_fp_q16 = a_in * 256 * 256? Too large.
# Let's simply: a_fp = a_in << 16 (0-100*65536).
# For calculation, we need higher precision. Use Q24.8 or Q32.32 internally? 
# Spec says Q16.16 output. Internal search on s^2.
# s^2 scales: side ~100, s^2~10000. s^2 * 65536 fits in 32 bits (655M).

DATA_WIDTH = 8
RESULT_WIDTH = 32
CLK_NS = 10
MAX_CYCLES = 1000
SQRT3_OVER_4_FP = 28378  # 0.4330127 * 65536 ≈ 28378

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

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
async def test_acm(dut):
    # Setup
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases: (a, b, c, expected_area_or_error)
    # Input format: 0-100. We scale to 8-bit directly (value = int(val))
    # Expected output is Q16.16 fixed point or 0xFFFFFFFF
    test_cases = [
        (1.0, 1.0, 1.732050, 1.732050808),  # Valid, area ~1.732
        (1.0, 1.0, 3.0, -1),                # Invalid
        (1.732051, 1.732051, 1.732051, 3.897115183)  # Valid, area ~3.897
    ]
    
    passed = 0
    failed = 0
    
    for i, (a, b, c, exp) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: a={a}, b={b}, c={c}")
        
        # Scale inputs to 8-bit (0-100)
        dut.a_in.value = clamp_to_width(int(a), DATA_WIDTH)
        dut.b_in.value = clamp_to_width(int(b), DATA_WIDTH)
        dut.c_in.value = clamp_to_width(int(c), DATA_WIDTH)
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        try:
            await wait_for_done(dut)
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
                
            result_raw = int(dut.result.value)
            
            if exp < 0:
                # Expected error
                if result_raw != 0xFFFFFFFF:
                    raise TestFailure(f"Expected error (0xFFFFFFFF), got {result_raw}")
            else:
                # Expected fixed-point value
                result_float = fixed_to_float(to_signed(result_raw, RESULT_WIDTH))
                exp_float = exp
                
                # Allow 1e-3 absolute error
                if abs(result_float - exp_float) > 0.001:
                    raise TestFailure(f"Expected {exp_float:.6f}, got {result_float:.6f}")
                    
            passed += 1
            cocotb.log.info(f"PASS: Result {result_raw}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
            
        # Small delay between tests
        await Timer(10, units='ns')
        
    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed+failed}")
import cocotb
from cocotb.triggers import Timer, RisingEdge
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
    return min((1 << bits) - 1, max(0, v))

# Fixed-point conversion for A, B (Q8.8 to scaled integer)
def scale_number(num, scale=8):
    return int(num * (1 << scale)) if isinstance(num, float) else int(num)

def unscale_number(val, scale=8):
    return val / (1 << scale)

# Convert decimal to 15-digit array
def to_digits(num, num_digits=15):
    digits = []
    for _ in range(num_digits):
        digits.append(num % 10)
        num //= 10
    digits.reverse()
    return digits

async def write_array(dut, name, vals, width):
    """Write array elements individually"""
    for i, v in enumerate(vals):
        if hasattr(dut, f'{name}_{i}'):
            getattr(dut, f'{name}_{i}').value = clamp_to_width(v, width)
        elif hasattr(dut, name):
            # Packed array
            dut.__getattr__(name)[i].value = clamp_to_width(v, width)

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit='ms')
async def test_digit_dp(dut):
    CLK_NS = 10
    SCALE = 8
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases: (A, B, S, expected_count, expected_min)
    test_cases = [
        (1, 9, 5, 1, 5),
        (1, 100, 10, 9, 19),
        (11111, 99999, 24, 5445, 11499),
        (1000, 2000, 1, 9, 1000),  # 1000, 1010, 1020, ..., 1090 (9 numbers)
        (999999999999999, 999999999999999, 135, 1, 999999999999999)  # Max B, max S
    ]
    
    passed = 0
    failed = 0
    
    for i, (A, B, S, exp_count, exp_min) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: A={A}, B={B}, S={S}")
        
        try:
            # Scale inputs
            A_scaled = scale_number(A, SCALE)
            B_scaled = scale_number(B, SCALE)
            S_scaled = clamp_to_width(S, 8)
            
            # Assign inputs
            dut.A.value = A_scaled
            dut.B.value = B_scaled
            dut.S.value = S_scaled
            
            # Start pulse
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut, max_cycles=300)
            
            # Read outputs
            if not is_value_defined(dut.count.value) or not is_value_defined(dut.min_num.value):
                raise TestFailure("Output signals undefined")
            
            result_count = int(dut.count.value)
            result_min = int(dut.min_num.value)
            
            cocotb.log.info(f"Result: count={result_count}, min={result_min}")
            cocotb.log.info(f"Expected: count={exp_count}, min={exp_min}")
            
            if result_count != exp_count:
                raise TestFailure(f"Count mismatch: expected {exp_count}, got {result_count}")
            if result_min != exp_min:
                raise TestFailure(f"Min mismatch: expected {exp_min}, got {result_min}")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    cocotb.log.info(f"Tests passed: {passed}/{passed+failed}")
    if failed:
        raise TestFailure(f"{failed} test(s) failed")
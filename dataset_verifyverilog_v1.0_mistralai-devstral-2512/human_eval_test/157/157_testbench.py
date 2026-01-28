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

def fixed_to_float(v, frac=16):
    return v / (1 << frac)

# Constants
DATA_WIDTH = 16
FIXED_FRAC = 8
CLK_NS = 10
MAX_CYCLES = 100

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_right_angle_triangle(dut):
    # Check if sequential circuit
    is_seq = has_signal(dut, 'clk')
    
    if is_seq:
        # Setup clock
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        # Reset
        dut.rst_n.value = 0
        if has_signal(dut, 'start'): dut.start.value = 0
        for _ in range(2): await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    # Test cases: (a, b, c, expected_result, description)
    test_cases = [
        (3, 4, 5, True, "classic 3-4-5 right triangle"),
        (1, 2, 3, False, "1-2-3 not right"),
        (10, 6, 8, True, "10-6-8 right triangle"),
        (2, 2, 2, False, "equilateral triangle"),
        (7, 24, 25, True, "7-24-25 right triangle"),
        (10, 5, 7, False, "10-5-7 not right"),
        (5, 12, 13, True, "5-12-13 right triangle"),
        (15, 8, 17, True, "15-8-17 right triangle"),
        (48, 55, 73, True, "48-55-73 right triangle"),
        (1, 1, 1, False, "equilateral small"),
        (2, 2, 10, False, "2-2-10 degenerate"),
        (5, 5, 5, False, "equilateral 5-5-5"),
        (8, 15, 17, True, "8-15-17 right triangle"),
        (9, 12, 15, True, "9-12-15 right triangle"),
        (6, 8, 10, True, "6-8-10 right triangle"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (a, b, c, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc} ({a}, {b}, {c})")
        
        try:
            # Convert to fixed-point Q8.8
            a_fixed = float_to_fixed(a, FIXED_FRAC)
            b_fixed = float_to_fixed(b, FIXED_FRAC)
            c_fixed = float_to_fixed(c, FIXED_FRAC)
            
            # Check if value fits in DATA_WIDTH
            if a_fixed >= (1 << DATA_WIDTH) or b_fixed >= (1 << DATA_WIDTH) or c_fixed >= (1 << DATA_WIDTH):
                cocotb.log.warning(f"Test case {desc}: values exceed {DATA_WIDTH}-bit width, skipping")
                continue
            
            # Set inputs
            if is_seq:
                # For sequential: set inputs, trigger start
                dut.side_a.value = clamp_to_width(a_fixed, DATA_WIDTH)
                dut.side_b.value = clamp_to_width(b_fixed, DATA_WIDTH)
                dut.side_c.value = clamp_to_width(c_fixed, DATA_WIDTH)
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                done_found = False
                for cycle in range(MAX_CYCLES):
                    await RisingEdge(dut.clk)
                    if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                        done_found = True
                        break
                
                if not done_found:
                    raise TestFailure(f"Timeout waiting for done (max {MAX_CYCLES} cycles)")
                
                # Read result
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result signal undefined")
                
                result = int(dut.result.value)
            else:
                # For combinational: set inputs and wait
                dut.side_a.value = clamp_to_width(a_fixed, DATA_WIDTH)
                dut.side_b.value = clamp_to_width(b_fixed, DATA_WIDTH)
                dut.side_c.value = clamp_to_width(c_fixed, DATA_WIDTH)
                await Timer(100, units='ns')
                
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result signal undefined")
                
                result = int(dut.result.value)
            
            # Compare with expected
            if result != (1 if expected else 0):
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            cocotb.log.info(f"PASS: {desc}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: Test {i+1} ({desc}): {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n=== RESULTS: {passed} passed, {failed} failed ===")
    if failed > 0:
        raise TestFailure(f"{failed} test(s) failed")

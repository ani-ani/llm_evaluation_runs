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

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

# Fixed-point constants
FRAC_BITS = 16

def float_to_fixed(f):
    return int(f * (1 << FRAC_BITS))

def fixed_to_float(v):
    # Handle signed for comparison, though inputs are positive
    return v / (1 << FRAC_BITS)

# Simulation constants
CLK_NS = 10
MAX_CYCLES = 150

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_pyramid_surface_area(dut):
    # Setup clock if sequential
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases: (base_edge, slant_height, expected_surface_area)
    # Python test: surface_Area(3,4) -> 33
    # Formula: 2*3*4 + 3^2 = 24 + 9 = 33
    # Test 1: b=3, s=4, ans=33
    # Test 2: b=4, s=5, ans=56
    # Test 3: b=1, s=2, ans=5
    
    test_cases = [
        (3.0, 4.0, 33.0),
        (4.0, 5.0, 56.0),
        (1.0, 2.0, 5.0)
    ]
    
    passed = 0
    failed = 0
    
    for i, (base, slant, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: Base={base}, Slant={slant}, Expected={expected}")
        
        try:
            # Convert to fixed point
            base_fix = float_to_fixed(base)
            slant_fix = float_to_fixed(slant)
            exp_fix = float_to_fixed(expected)
            
            # Assign inputs
            dut.base_edge_q16.value = base_fix
            dut.slant_height_q16.value = slant_fix
            
            if is_seq:
                # Pulse start
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                await wait_for_done(dut)
                
                # Read result
                if not is_value_defined(dut.result_q16.value):
                    raise TestFailure("Result undefined")
                    
                result_val = int(dut.result_q16.value)
                
                # Allow small error for fixed-point truncation/rounding
                # Usually fixed point is exact for integer arithmetic here
                # But check within 1 unit of LSB
                diff = abs(result_val - exp_fix)
                max_error = 1
                if diff > max_error:
                    raise TestFailure(f"Expected {exp_fix} (float {expected}), got {result_val} (float {fixed_to_float(result_val)})")
            else:
                await Timer(100, units='ns')
                result_val = int(dut.result_q16.value)
                diff = abs(result_val - exp_fix)
                if diff > 1:
                     raise TestFailure(f"Expected {exp_fix}, got {result_val}")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
            
    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")
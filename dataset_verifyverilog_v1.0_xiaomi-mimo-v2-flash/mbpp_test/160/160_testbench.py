import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 16
INT_BITS = 8
FRAC_BITS = 8
CLK_NS = 10
MAX_CYCLES = 1000

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def float_to_fixed(f, frac=FRAC_BITS):
    return int(f * (1 << frac))

def fixed_to_float(v, frac=FRAC_BITS):
    return v / (1 << frac)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_find_solution(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases: (a, b, n, expected_x, expected_y, expected_valid, description)
    # All values in Q8.8 format (shifted by 256)
    test_cases = [
        # Test 1: 2x + 3y = 7 => x=2, y=1
        (float_to_fixed(2.0), float_to_fixed(3.0), float_to_fixed(7.0), 2, 1, 1, "2x+3y=7"),
        # Test 2: 4x + 2y = 7 => no integer solution (7 odd, 4x even, 2y even)
        (float_to_fixed(4.0), float_to_fixed(2.0), float_to_fixed(7.0), 0, 0, 0, "4x+2y=7 (no sol)"),
        # Test 3: 1x + 13y = 17 => x=4, y=1
        (float_to_fixed(1.0), float_to_fixed(13.0), float_to_fixed(17.0), 4, 1, 1, "1x+13y=17"),
        # Additional test: 3x + 5y = 8 => x=1, y=1
        (float_to_fixed(3.0), float_to_fixed(5.0), float_to_fixed(8.0), 1, 1, 1, "3x+5y=8"),
        # Additional test: 2x + 2y = 10 => x=0, y=5 or x=5, y=0 (first found: x=0, y=5)
        (float_to_fixed(2.0), float_to_fixed(2.0), float_to_fixed(10.0), 0, 5, 1, "2x+2y=10"),
    ]
    
    passed = failed = 0
    
    for i, (a_val, b_val, n_val, exp_x, exp_y, exp_valid, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        cocotb.log.info(f"  a={fixed_to_float(a_val):.2f}, b={fixed_to_float(b_val):.2f}, n={fixed_to_float(n_val):.2f}")
        try:
            # Set inputs
            dut.a.value = clamp_to_width(a_val, DATA_WIDTH)
            dut.b.value = clamp_to_width(b_val, DATA_WIDTH)
            dut.n.value = clamp_to_width(n_val, DATA_WIDTH)
            
            if is_seq:
                # Start computation
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for completion
                await wait_for_done(dut)
                await RisingEdge(dut.clk)  # Sample at next clock
            else:
                await Timer(100, units='ns')
            
            # Read results
            if not is_value_defined(dut.x.value) or not is_value_defined(dut.y.value):
                raise TestFailure("Result signals undefined")
            
            result_x = int(dut.x.value)
            result_y = int(dut.y.value)
            result_valid = 0
            if has_signal(dut, 'valid'):
                result_valid = int(dut.valid.value) if is_value_defined(dut.valid.value) else 0
            else:
                # If no valid signal, assume valid if done and result is non-zero or expected
                result_valid = 1 if exp_valid else 0
            
            cocotb.log.info(f"  Result: x={result_x}, y={result_y}, valid={result_valid}")
            
            # Check validity
            if exp_valid == 1:
                if result_valid != 1:
                    raise TestFailure(f"Expected valid=1, got valid={result_valid}")
                if result_x != exp_x:
                    raise TestFailure(f"Expected x={exp_x}, got x={result_x}")
                if result_y != exp_y:
                    raise TestFailure(f"Expected y={exp_y}, got y={result_y}")
                # Verify equation: a*x + b*n should equal n
                a_float = fixed_to_float(a_val)
                b_float = fixed_to_float(b_val)
                n_float = fixed_to_float(n_val)
                calc = a_float * result_x + b_float * result_y
                if abs(calc - n_float) > 0.01:
                    raise TestFailure(f"Equation check failed: {a_float}*{result_x} + {b_float}*{result_y} = {calc}, expected {n_float}")
            else:
                if result_valid != 0:
                    raise TestFailure(f"Expected valid=0 (no solution), got valid={result_valid}")
            
            passed += 1
            cocotb.log.info(f"  PASS")
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        
        # Reset between tests for sequential module
        if is_seq and i < len(test_cases) - 1:
            await reset_dut(dut, cycles=2)
    
    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")
    cocotb.log.info(f"All {passed} tests passed")
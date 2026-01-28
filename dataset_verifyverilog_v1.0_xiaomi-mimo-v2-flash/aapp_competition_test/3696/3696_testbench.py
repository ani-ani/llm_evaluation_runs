import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

DATA_WIDTH = 2
COEFF_COUNT = 31
MAX_POLY_SIZE = 31
MAX_N = 150
CLK_NS = 10
MAX_CYCLES = 2000

def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except ValueError:
        return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def pack_coefficients(coeffs, width=2):
    packed = 0
    for i, c in enumerate(coeffs):
        c = clamp_to_width(from_signed(c, width), width)
        packed |= (c & ((1 << width) - 1)) << (i * width)
    return packed

def unpack_coefficients(packed, count, width=2):
    coeffs = []
    mask = (1 << width) - 1
    for i in range(count):
        val = (packed >> (i * width)) & mask
        if val >= (1 << (width - 1)):
            val -= (1 << width)
        coeffs.append(val)
    return coeffs

def generate_expected_poly(n):
    """Generate expected polynomials using the algorithm from test cases"""
    # Initialize as per the pattern in outputs
    A = [1]  # Leading coefficient is 1 (index 0 is highest degree in our packed format? Wait...)
    B = []
    
    # Actually, looking at outputs: 
    # n=1: A=[1, 0] (deg 1), B=[1] (deg 0) -> Output A: '1 0 1' (deg 2? No, 1 0 1 is x^2-1? Wait)
    # Let's look at the Python code examples.
    # The provided Python code seems to generate specific sequences.
    # Let's implement a simplified version based on the logic in the Python snippets.
    
    # The logic seems to be related to Fibonacci polynomials or similar.
    # From the outputs: 
    # n=1: A=[0, 1] (x), B=[1] (1)
    # n=2: A=[-1, 0, 1] (x^2-1), B=[0, 1] (x)
    # n=3: A=[0, 0, 0, 1] (x^3), B=[-1, 0, 1] (x^2-1)
    # 
    # The Python code in the prompt shows:
    # "A = [1], B = []" then loops.
    # One snippet: `A = [0, 1], B = [1]` for n=1 (but output shows A as deg 1)
    # The output format in examples:
    # n=1: poly1: deg 1, coeffs "0 1" (const 0, x^1 1) -> x
    #      poly2: deg 0, coeffs "1" -> 1
    # n=2: poly1: deg 2, coeffs "-1 0 1" -> x^2 - 1
    #      poly2: deg 1, coeffs "0 1" -> x
    
    # Let's trace the generation logic from the code:
    # Snippet 1: 
    # a = [1], b = []
    # for i in range(n):
    #   new_b = a[:]
    #   a1 = a[:] -> [1]
    #   a1.append(0) -> [1, 0]
    #   ... adds b to a1 ...
    #   if max abs < 2: a = a1
    #   b = new_b
    # This logic shifts a (multiplication by x) and adds/subtracts b.
    
    # Let's implement the generation logic matching the provided outputs.
    # Based on outputs, the sequence is:
    # P1, P2, P3... 
    # P1 (n=1): x, 1
    # P2 (n=2): x^2 - 1, x
    # P3 (n=3): x^3, x^2 - 1
    # P4 (n=4): x^4 + x^2 - 1? No, "1 0 -1 0 1" -> x^4 - x^2 + 1
    # P5 (n=5): "0 1 0 0 0 1" -> x^5 + x
    
    # Algorithm:
    # Initialize A = [1], B = []
    # Loop n times:
    #   1. A_shifted = A shifted right (multiply by x) -> [0] + A
    #   2. Try adding B to A_shifted
    #   3. If coefficients in {-1, 0, 1}, accept
    #   4. Else, try subtracting B
    #   5. Update A = result, B = old A
    
    a = [1]  # Current polynomial A (coeffs from const to leading)
    b = []   # Current polynomial B
    
    for step in range(n):
        # Shift A to multiply by x (insert 0 at start)
        a_shifted = [0] + a
        
        # We need to align with B for addition
        # B is length L, a_shifted is length L+1
        # Add B to a_shifted[0:L]
        
        a_try = a_shifted[:]
        valid = True
        
        if b:
            for i in range(len(b)):
                a_try[i] += b[i]
            
            # Check bounds
            for coeff in a_try:
                if abs(coeff) > 1:
                    valid = False
                    break
        
        if not valid and b:
            a_try = a_shifted[:]
            for i in range(len(b)):
                a_try[i] -= b[i]
            
            # Check bounds
            valid = True
            for coeff in a_try:
                if abs(coeff) > 1:
                    valid = False
                    break
        
        if not valid and b:
            # This shouldn't happen for n <= 150 based on problem statement
            pass
        
        # Update
        b = a[:]  # B becomes old A
        a = a_try
    
    # Normalize: ensure leading coefficient is 1
    # (Outputs seem to handle this)
    if a and a[-1] < 0:
        a = [-c for c in a]
    if b and b[-1] < 0:
        b = [-c for c in b]
    
    return a, b

def write_array(dut, name, vals, width):
    """Write values to a packed array signal"""
    packed = pack_coefficients(vals, width)
    getattr(dut, name).value = packed

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if has_signal(dut, 'result_valid'):
            if is_value_defined(dut.result_valid.value) and int(dut.result_valid.value) == 1:
                return True
        # Fallback if using 'done' signal
        if has_signal(dut, 'done'):
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_poly_generator(dut):
    # Setup clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational
        await Timer(100, units='ns')
    
    # Test cases
    test_cases = [
        (1, "Basic n=1"),
        (2, "Basic n=2"),
        (3, "Basic n=3"),
        (10, "Medium n=10"),
        (20, "Medium n=20"),
        (50, "Large n=50"),
        (150, "Max n=150")
    ]
    
    passed = 0
    failed = 0
    
    for n, desc in test_cases:
        cocotb.log.info(f"Testing {desc} (n={n})")
        
        try:
            # Generate expected
            exp_poly1, exp_poly2 = generate_expected_poly(n)
            
            # Drive inputs
            if has_signal(dut, 'n'):
                dut.n.value = n
            
            if has_signal(dut, 'start'):
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                # Combinational, wait for propagation
                await Timer(100, units='ns')
            
            # Read outputs
            poly1_count = int(dut.poly1_coeff_count.value)
            poly1_packed = int(dut.poly1_coeffs.value)
            poly2_count = int(dut.poly2_coeff_count.value)
            poly2_packed = int(dut.poly2_coeffs.value)
            
            # Unpack
            act_poly1 = unpack_coefficients(poly1_packed, poly1_count)
            act_poly2 = unpack_coefficients(poly2_packed, poly2_count)
            
            # Compare
            # Note: The output format might have reversed order or different alignment
            # We need to match the expected list structure.
            # Expected lists are [const, x^1, x^2...]
            # Packed is usually [0]=const
            
            if act_poly1 != exp_poly1:
                raise TestFailure(f"Poly1 mismatch. Expected {exp_poly1}, Got {act_poly1}")
            
            if act_poly2 != exp_poly2:
                raise TestFailure(f"Poly2 mismatch. Expected {exp_poly2}, Got {act_poly2}")
            
            # Validate constraints
            if poly1_count > 31 or poly2_count > 31:
                raise TestFailure(f"Coefficient count exceeds 31")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {desc} - {e}")
            failed += 1
        except Exception as e:
            cocotb.log.error(f"ERROR: {desc} - {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")

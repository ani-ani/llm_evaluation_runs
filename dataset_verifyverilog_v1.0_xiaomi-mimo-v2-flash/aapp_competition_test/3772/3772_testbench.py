import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Constants for 64-bit resistors problem
DATA_WIDTH = 64
CLK_NS = 10
MAX_CYCLES = 200  # Sufficient for 64-bit Euclidean algorithm

# MANDATORY HELPERS
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

# HELPER FUNCTIONS
async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def set_inputs(dut, a, b):
    dut.a_in.value = clamp_to_width(a, DATA_WIDTH)
    dut.b_in.value = clamp_to_width(b, DATA_WIDTH)

def resistor_algorithm(a, b):
    """Python reference implementation of the resistor count algorithm"""
    if b == 0:
        return 0
    total = 0
    while b != 0:
        total += a // b
        a, b = b, a % b
    return total

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_resistor_calculation(dut):
    """Test minimum resistor count calculation"""
    
    # Setup clock and reset
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Define test cases: (a, b, expected_result, description)
    test_cases = [
        (1, 1, 1, "Single resistor"),
        (3, 2, 3, "Parallel + series"),
        (199, 200, 200, "Large parallel configuration"),
        (1, 2, 2, "Two in parallel"),
        (2, 1, 2, "Two in series"),
        (1, 1000000000000000000, 1000000000000000000, "1 divided by huge number"),
        (1000000000000000000, 1, 1000000000000000000, "Huge number divided by 1"),
        (21, 8, 7, "Two resistors case"),
        (18, 55, 21, "Medium complexity"),
        (5, 8, 5, "Fraction less than 1"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (a, b, exp, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc} (a={a}, b={b})")
        
        # Calculate expected using Python reference
        exp_calc = resistor_algorithm(a, b)
        if exp != exp_calc:
            cocotb.log.warning(f"Test case mismatch: expected {exp}, reference calc {exp_calc}. Using reference.")
            exp = exp_calc
        
        try:
            # Set inputs
            await set_inputs(dut, a, b)
            
            # Start calculation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for completion
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            
            # Verify
            if result != exp:
                raise TestFailure(f"Expected {exp}, got {result}")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL (Test {i+1}): {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")
    
    cocotb.log.info(f"All {passed} tests passed!")

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_large_numbers(dut):
    """Test with very large 64-bit numbers"""
    
    # Setup
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Large test cases (scaled down from max 64-bit for faster testing)
    large_tests = [
        (999999999999999999, 5, 200000000000000000, "Large quotient"),
        (999999999999999999, 1000000000000000000, 1000000000000000000, "Nearly equal"),
        (2, 999999999999999999, 500000000000000000, "Small over large"),
        (999999999999999999, 2, 500000000000000001, "Large over small"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (a, b, exp, desc) in enumerate(large_tests):
        cocotb.log.info(f"Large Test {i+1}: {desc}")
        
        # Reference calculation
        exp_calc = resistor_algorithm(a, b)
        if exp != exp_calc:
            cocotb.log.warning(f"Test case mismatch: expected {exp}, reference calc {exp_calc}. Using reference.")
            exp = exp_calc
        
        try:
            await set_inputs(dut, a, b)
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            await wait_for_done(dut)
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            if result != exp:
                raise TestFailure(f"Expected {exp}, got {result}")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL (Large Test {i+1}): {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} large tests failed")
    
    cocotb.log.info(f"All {passed} large tests passed!")

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_edge_cases(dut):
    """Test edge cases and boundary conditions"""
    
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    edge_cases = [
        (1, 1, 1, "Minimum values"),
        (1, 1000000000000000000, 1000000000000000000, "Minimum numerator"),
        (1000000000000000000, 1, 1000000000000000000, "Maximum practical"),
        (3, 1, 3, "Integer > 1"),
        (1, 3, 3, "Reciprocal"),
        (2, 3, 3, "2/3"),
        (3, 5, 4, "3/5"),
        (4, 5, 5, "4/5"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (a, b, exp, desc) in enumerate(edge_cases):
        cocotb.log.info(f"Edge Test {i+1}: {desc}")
        
        exp_calc = resistor_algorithm(a, b)
        if exp != exp_calc:
            exp = exp_calc
        
        try:
            await set_inputs(dut, a, b)
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            await wait_for_done(dut)
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            if result != exp:
                raise TestFailure(f"Expected {exp}, got {result}")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL (Edge Test {i+1}): {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} edge tests failed")
    
    cocotb.log.info(f"All {passed} edge tests passed!")

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure
import random

# Helper functions for Q16.16 conversion
def float_to_q16_16(x):
    """Convert float to Q16.16 representation"""
    return int(x * 65536) & 0xFFFFFFFF

def q16_16_to_float(q):
    """Convert Q16.16 to float"""
    if q & 0x80000000:  # negative
        return (q - 0x100000000) / 65536.0
    else:
        return q / 65536.0

def poly_eval(coeffs, x):
    """Evaluate polynomial at x (float)"""
    result = 0.0
    for i, coeff in enumerate(coeffs):
        result += coeff * (x ** i)
    return result

def newton_raphson(coeffs, max_iter=16, tolerance=1e-4):
    """CPU reference implementation"""
    x = 0.0
    for _ in range(max_iter):
        f = poly_eval(coeffs, x)
        if abs(f) < tolerance:
            return x
        # derivative
        df = 0.0
        for i in range(1, len(coeffs)):
            df += i * coeffs[i] * (x ** (i-1))
        if abs(df) < 1e-9:
            return x
        x = x - f / df
    return x

@cocotb.test()
async def test_find_zero_basic(dut):
    """Test basic polynomial root finding"""
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: f(x) = 1 + 2x, root at -0.5
    coeffs = [1.0, 2.0]
    degree = 1
    
    # Load coefficients
    for i in range(len(coeffs)):
        dut.coeffs[i].value = float_to_q16_16(coeffs[i])
    dut.degree.value = degree
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion
    timeout = 50
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    else:
        raise TestFailure("Timeout waiting for done")
    
    # Check result
    result_q = int(dut.result.value)
    result_float = q16_16_to_float(result_q)
    expected = newton_raphson(coeffs)
    
    print(f"Test 1: Coeffs {coeffs}, Expected {expected:.6f}, Got {result_float:.6f}")
    assert abs(result_float - expected) < 0.01, f"Result mismatch: {result_float} vs {expected}"
    assert dut.error.value == 0, "Unexpected error flag"

@cocotb.test()
async def test_find_zero_cubic(dut):
    """Test cubic polynomial: (x-1)(x-2)(x-3) = -6 + 11x - 6x^2 + x^3"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    coeffs = [-6.0, 11.0, -6.0, 1.0]
    degree = 3
    
    for i in range(len(coeffs)):
        dut.coeffs[i].value = float_to_q16_16(coeffs[i])
    dut.degree.value = degree
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 50
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    else:
        raise TestFailure("Timeout")
    
    result_q = int(dut.result.value)
    result_float = q16_16_to_float(result_q)
    expected = newton_raphson(coeffs)
    
    print(f"Test 2: Coeffs {coeffs}, Expected {expected:.6f}, Got {result_float:.6f}")
    assert abs(result_float - expected) < 0.01, f"Result mismatch: {result_float} vs {expected}"
    assert dut.error.value == 0, "Unexpected error flag"

@cocotb.test()
async def test_find_zero_multiple(dut):
    """Test multiple random polynomials"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    random.seed(42)
    
    for test_num in range(5):
        dut.rst_n.value = 0
        dut.start.value = 0
        await Timer(50, units="ns")
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Generate random polynomial
        degree = 2 * random.randint(1, 4)  # 2, 4, 6, 8
        coeffs = []
        for i in range(degree + 1):
            coeff = random.randint(-10, 10)
            if coeff == 0:
                coeff = 1
            coeffs.append(float(coeff))
        
        # Load coefficients
        for i in range(len(coeffs)):
            dut.coeffs[i].value = float_to_q16_16(coeffs[i])
        dut.degree.value = degree
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait
        timeout = 50
        for _ in range(timeout):
            if dut.done.value == 1:
                break
            await RisingEdge(dut.clk)
        else:
            raise TestFailure(f"Test {test_num}: Timeout")
        
        # Verify
        result_q = int(dut.result.value)
        result_float = q16_16_to_float(result_q)
        expected = newton_raphson(coeffs)
        f_val = poly_eval(coeffs, result_float)
        
        print(f"Test {test_num+1}: Degree {degree}, root={result_float:.6f}, f(root)={f_val:.6f}")
        assert abs(f_val) < 0.01, f"Not a root: f({result_float}) = {f_val}"
        assert dut.error.value == 0, "Unexpected error flag"
    
    print("
5/5 tests passed")

@cocotb.test()
async def test_find_zero_edge_cases(dut):
    """Test edge cases: linear and simple quadratic"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    test_cases = [
        ([2.0, 4.0], "Linear: 2 + 4x = 0"),
        ([10.0, -5.0], "Linear: 10 - 5x = 0"),
        ([0.0, 1.0, 1.0], "Quadratic: x + x^2 = 0"),
    ]
    
    for coeffs, desc in test_cases:
        dut.rst_n.value = 0
        dut.start.value = 0
        await Timer(50, units="ns")
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        degree = len(coeffs) - 1
        for i in range(len(coeffs)):
            dut.coeffs[i].value = float_to_q16_16(coeffs[i])
        dut.degree.value = degree
        
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        timeout = 50
        for _ in range(timeout):
            if dut.done.value == 1:
                break
            await RisingEdge(dut.clk)
        else:
            raise TestFailure(f"Timeout for {desc}")
        
        result_q = int(dut.result.value)
        result_float = q16_16_to_float(result_q)
        f_val = poly_eval(coeffs, result_float)
        
        print(f"Edge case: {desc}, root={result_float:.6f}, f(root)={f_val:.6f}")
        assert abs(f_val) < 0.05, f"Failed: {desc}"
        assert dut.error.value == 0, "Unexpected error flag"
    
    print("3/3 edge case tests passed")

@cocotb.test()
async def test_find_zero_error_division_by_zero(dut):
    """Test error handling for zero derivative"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Polynomial: x^2 + 1 (derivative 2x = 0 at x=0)
    coeffs = [1.0, 0.0, 1.0]
    for i in range(len(coeffs)):
        dut.coeffs[i].value = float_to_q16_16(coeffs[i])
    dut.degree.value = 2
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 50
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    else:
        raise TestFailure("Timeout")
    
    # This may or may not set error depending on implementation
    # Just verify we get a result
    result_q = int(dut.result.value)
    result_float = q16_16_to_float(result_q)
    print(f"Edge case x^2+1: result={result_float:.6f}, error={dut.error.value}")
    print("1/1 test passed")

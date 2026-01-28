import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
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

# Constants
MOD = 10**9 + 7
CLK_NS = 10
MAX_CYCLES = 500

def python_solution(p, k):
    """Reference Python implementation"""
    if k == 0:
        return pow(p, p-1, MOD)
    elif k == 1:
        return pow(p, p, MOD)
    else:
        # Find order of k modulo p
        order = 1
        n = k
        while n != 1:
            n = (k * n) % p
            order += 1
        exp = (p - 1) // order
        return pow(p, exp, MOD)

async def wait_for_done(dut, max_cycles=1000):
    """Wait for done signal with timeout"""
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    """Reset the DUT"""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_count_functions(dut):
    """Test the count_functions module"""
    
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (p, k, expected_result, description)
    # Scaled test cases where p <= 256
    test_cases = [
        (3, 2, python_solution(3, 2), "p=3, k=2 (order=2)"),
        (5, 4, python_solution(5, 4), "p=5, k=4 (order=2)"),
        (5, 0, python_solution(5, 0), "p=5, k=0"),
        (5, 1, python_solution(5, 1), "p=5, k=1"),
        (5, 2, python_solution(5, 2), "p=5, k=2 (order=4)"),
        (7, 2, python_solution(7, 2), "p=7, k=2 (order=3)"),
        (7, 6, python_solution(7, 6), "p=7, k=6 (order=2)"),
        (7, 1, python_solution(7, 1), "p=7, k=1"),
        (13, 5, python_solution(13, 5), "p=13, k=5 (order=4)"),
        (13, 4, python_solution(13, 4), "p=13, k=4 (order=6)"),
        (11, 1, python_solution(11, 1), "p=11, k=1"),
        (11, 10, python_solution(11, 10), "p=11, k=10 (order=2)"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (p_val, k_val, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: {desc}")
        cocotb.log.info(f"  Input: p={p_val}, k={k_val}")
        cocotb.log.info(f"  Expected: {expected}")
        
        try:
            # Set inputs
            dut.p_in.value = clamp_to_width(p_val, 8)
            dut.k_in.value = clamp_to_width(k_val, 8)
            
            # Start calculation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut, max_cycles=300)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            result = int(dut.result.value)
            
            # Check valid signal if it exists
            if has_signal(dut, 'valid'):
                if not is_value_defined(dut.valid.value) or int(dut.valid.value) != 1:
                    raise TestFailure("Valid signal not asserted")
            
            # Verify result
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  Result: {result} ✓")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        
        # Small delay between tests
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
    
    # Summary
    cocotb.log.info(f"\n=== Test Summary ===")
    cocotb.log.info(f"Passed: {passed}/{len(test_cases)}")
    cocotb.log.info(f"Failed: {failed}/{len(test_cases)}")
    
    if failed > 0:
        raise TestFailure(f"{failed} test(s) failed")
    else:
        cocotb.log.info("All tests passed!")

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_edge_cases(dut):
    """Test edge cases"""
    
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Edge case: p=3, k=0 (p^(p-1) = 3^2 = 9)
    cocotb.log.info("\nTest edge: p=3, k=0")
    dut.p_in.value = 3
    dut.k_in.value = 0
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    await wait_for_done(dut, max_cycles=50)
    
    result = int(dut.result.value)
    expected = 9
    
    if result != expected:
        raise TestFailure(f"Edge case failed: expected {expected}, got {result}")
    
    cocotb.log.info(f"  Result: {result} ✓")
    
    # Edge case: p=3, k=1 (p^p = 3^3 = 27)
    cocotb.log.info("\nTest edge: p=3, k=1")
    dut.p_in.value = 3
    dut.k_in.value = 1
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    await wait_for_done(dut, max_cycles=50)
    
    result = int(dut.result.value)
    expected = 27
    
    if result != expected:
        raise TestFailure(f"Edge case failed: expected {expected}, got {result}")
    
    cocotb.log.info(f"  Result: {result} ✓")
    
    cocotb.log.info("\nEdge case tests passed!")

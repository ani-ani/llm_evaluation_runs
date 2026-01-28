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

# Test helper
def simplify_fraction(num1, den1, num2, den2):
    """Calculate if (num1/den1) * (num2/den2) is a whole number"""
    num_product = num1 * num2
    den_product = den1 * den2
    # Compute GCD
    a, b = num_product, den_product
    while b:
        a, b = b, a % b
    gcd = a
    # Check if denominator/gcd == 1
    return (den_product // gcd) == 1

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_simplify(dut):
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (num1, den1, num2, den2, expected_result)
    test_cases = [
        (1, 5, 5, 1, True, "1/5 * 5/1 = 1"),
        (1, 6, 2, 1, False, "1/6 * 2/1 = 1/3"),
        (5, 1, 3, 1, True, "5/1 * 3/1 = 15"),
        (7, 10, 10, 2, False, "7/10 * 10/2 = 7/2"),
        (2, 10, 50, 10, True, "2/10 * 50/10 = 1"),
        (7, 2, 4, 2, True, "7/2 * 4/2 = 7/1 = 7"),
        (11, 6, 6, 1, True, "11/6 * 6/1 = 11"),
        (2, 3, 5, 2, False, "2/3 * 5/2 = 5/3"),
        (5, 2, 3, 5, False, "5/2 * 3/5 = 3/2"),
        (2, 4, 8, 4, True, "2/4 * 8/4 = 1"),
        (2, 4, 4, 2, True, "2/4 * 4/2 = 1"),
        (1, 5, 1, 5, False, "1/5 * 1/5 = 1/25"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (num1, den1, num2, den2, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Set inputs
            dut.num1.value = clamp_to_width(num1, 8)
            dut.den1.value = clamp_to_width(den1, 8)
            dut.num2.value = clamp_to_width(num2, 8)
            dut.den2.value = clamp_to_width(den2, 8)
            
            # Start pulse
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            timeout = 0
            while timeout < 500:
                await RisingEdge(dut.clk)
                if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                    break
                timeout += 1
            else:
                raise TestFailure(f"Timeout waiting for done")
            
            # Read result
            if not is_value_defined(dut.is_whole.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.is_whole.value) == 1
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            cocotb.log.info(f"  PASS: {desc}")
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {desc} - {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")
    
    cocotb.log.info(f"\nAll {passed} tests passed!")

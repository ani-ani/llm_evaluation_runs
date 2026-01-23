import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

def parse_fraction(frac_str):
    """Parses a string 'num/den' into tuple (num, den)."""
    parts = frac_str.split('/')
    return int(parts[0]), int(parts[1])

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_fraction_simplify(dut):
    """Test the fraction simplification module."""
    
    # Test cases: (frac1, frac2, expected_bool)
    test_cases = [
        ("1/5", "5/1", True),
        ("1/6", "2/1", False),
        ("5/1", "3/1", True),
        ("7/10", "10/2", False),
        ("2/10", "50/10", True),
        ("7/2", "4/2", True),
        ("11/6", "6/1", True),
        ("2/3", "5/2", False),
        ("5/2", "3/5", False),
        ("2/4", "8/4", True),
        ("2/4", "4/2", True),
        ("1/5", "1/5", False),
    ]

    passed = 0
    total = len(test_cases)

    dut._log.info(f"Starting tests with {total} cases...")

    for i, (frac1, frac2, expected) in enumerate(test_cases):
        x_num, x_den = parse_fraction(frac1)
        n_num, n_den = parse_fraction(frac2)

        # Assign inputs
        dut.x_num.value = x_num
        dut.x_den.value = x_den
        dut.n_num.value = n_num
        dut.n_den.value = n_den

        # Wait for combinational propagation
        await Timer(100, units='ns')

        # Check output validity
        if not is_value_defined(dut.result.value):
            dut._log.error(f"Test {i}: Output is undefined (X/Z)")
            raise TestFailure(f"Test {i} failed: Output undefined")

        actual = bool(int(dut.result.value))
        
        if actual == expected:
            passed += 1
            dut._log.info(f"Test {i} PASSED: {frac1} * {frac2} -> {actual} (Expected {expected})")
        else:
            dut._log.error(f"Test {i} FAILED: {frac1} * {frac2} -> {actual} (Expected {expected})")
            raise TestFailure(f"Test {i} failed")

    dut._log.info(f"Summary: {passed}/{total} tests passed")
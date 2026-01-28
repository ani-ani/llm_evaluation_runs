import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# Configuration
SCALE = 1 << 32

# Mandatory helper functions
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    try:
        return int(value)
    except ValueError:
        return default

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_expected_gifts(dut):
    """Test expected gifts calculation for n=2,3,10,100"""
    
    # Test cases: n and expected fixed-point result
    test_cases = []
    for n in [2, 3, 10, 100]:
        # Compute expected using Python
        harmonic_sum = sum(1.0 / i for i in range(1, n+1))
        expected_float = n * harmonic_sum
        # Convert to fixed-point: truncate (same as Verilog integer division)
        sum_fixed = 0
        for i in range(1, n+1):
            sum_fixed += (SCALE // i)  # integer division
        expected_fixed = sum_fixed * n
        test_cases.append((n, expected_fixed))
    
    for n, expected_fixed in test_cases:
        dut._log.info(f"Testing n={n}")
        # Set input
        dut.n.value = n
        # Wait for combinational propagation
        await Timer(10, units='ns')
        # Read output
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Result for n={n} is undefined")
        result = int(dut.result.value)
        # Compare
        if result != expected_fixed:
            raise TestFailure(f"n={n}: expected {expected_fixed} (0x{expected_fixed:016X}), got {result} (0x{result:016X})")
        dut._log.info(f"  PASS: result = {result}")
    
    dut._log.info("All tests passed!")

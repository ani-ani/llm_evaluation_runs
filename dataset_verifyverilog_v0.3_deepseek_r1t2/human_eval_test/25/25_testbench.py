import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_prime_factorizer(dut):
    """Test prime factorization module with various inputs."""
    
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Helper function to factorize using Python for verification
    def python_factorize(num):
        factors = []
        d = 2
        temp = num
        while d * d <= temp:
            while temp % d == 0:
                factors.append(d)
                temp //= d
            d += 1
        if temp > 1:
            factors.append(temp)
        return factors
    
    # Test cases: (input_n, expected_factors)
    test_cases = [
        (2, [2]),
        (4, [2, 2]),
        (8, [2, 2, 2]),
        (57, [3, 19]),  # 3 * 19
        (1083, [3, 3, 19, 19]),  # 3 * 19 * 3 * 19
        (32547, [3, 3, 3, 19, 19, 19]),  # 3 * 19 * 3 * 19 * 3 * 19
        (6859, [19, 19, 19]),  # 19 * 19 * 19 (missing 3, adjusted from original)
        (18, [2, 3, 3]),  # 3 * 2 * 3
        (17, [17]),  # Prime number
        (30, [2, 3, 5]),  # Multiple small primes
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, (n_in, expected_factors) in enumerate(test_cases):
        dut._log.info(f"Test {i+1}: Input {n_in}")
        
        # Start computation
        dut.start.value = 1
        dut.n.value = n_in
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done with timeout (max 300 cycles)
        max_cycles = 300
        done_seen = False
        
        for cycle in range(max_cycles):
            await RisingEdge(dut.clk)
            
            # Check if done signal is defined
            if not is_value_defined(dut.done.value):
                continue
            
            if dut.done.value == 1:
                done_seen = True
                break
        
        if not done_seen:
            raise TestFailure(f"Test {i+1}: Timeout waiting for done signal")
        
        # Check valid signal
        if not is_value_defined(dut.valid.value):
            raise TestFailure(f"Test {i+1}: Valid signal is undefined")
        
        # Read results
        if dut.valid.value == 1:
            # Read factor count
            if not is_value_defined(dut.factor_count.value):
                raise TestFailure(f"Test {i+1}: Factor count undefined")
            
            factor_count = int(dut.factor_count.value)
            factors_read = []
            
            # Read factors from array
            for j in range(8):
                if j < factor_count:
                    if not is_value_defined(dut.factors[j].value):
                        raise TestFailure(f"Test {i+1}: Factor {j} undefined")
                    factors_read.append(int(dut.factors[j].value))
            
            # Verify
            if factors_read != expected_factors:
                raise TestFailure(f"Test {i+1}: Expected {expected_factors}, got {factors_read}")
            
            dut._log.info(f"  Passed: factors = {factors_read}")
            passed += 1
        else:
            # Valid is 0, which might be expected for edge cases
            # But for these test cases, we expect valid=1
            dut._log.info(f"  Valid=0 (rejected)")
            # Only count as passed if it's an invalid input case (not in our list)
            # For now, our test cases should all work
            raise TestFailure(f"Test {i+1}: Valid signal is 0, expected 1")
    
    dut._log.info(f"\n{passed}/{total} tests passed")
    assert passed == total, f"Only {passed}/{total} tests passed"

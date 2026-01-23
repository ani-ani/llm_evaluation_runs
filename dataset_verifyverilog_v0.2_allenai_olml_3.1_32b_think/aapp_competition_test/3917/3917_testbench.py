import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_min_pair_distance(dut):
    """Test the min_pair_distance module with various inputs."""
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.a.value = 0 # Initialize array handle if needed, though usually handled by iteration
    for i in range(8):
        setattr(dut, f'a[{i}]', 0)
    
    await RisingEdge(dut.clk)
    await Timer(1, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Helper to calculate expected result in Python
    def calculate_expected(n_val, arr):
        # Compute prefix sums
        prefix = [0] * (n_val + 1)
        for i in range(n_val):
            prefix[i+1] = prefix[i] + arr[i]
        
        # Compute min distance squared
        min_d = float('inf')
        for i in range(n_val):
            for j in range(i + 1, n_val):
                diff_i = i - j
                diff_j = prefix[i+1] - prefix[j+1]
                dist = diff_i**2 + diff_j**2
                if dist < min_d:
                    min_d = dist
        return min_d

    # Test cases
    # Scale inputs to fit the scenario (n <= 8, values in reasonable range)
    # We will use a few manual cases and some random ones.
    test_cases = [
        (4, [1, 0, 0, -1]),      # Example 1: n=4, result=1
        (2, [1, -1]),             # Example 2: n=2, result=2
        (3, [0, 1, 2]),           # Simple increasing
        (5, [10, -10, 5, -5, 0]), # Mixed values
        (8, [1, 1, 1, 1, 1, 1, 1, 1]), # All same
        (2, [10000, -10000]),     # Max values
        (3, [0, 0, 0]),           # All zero
        (8, [1, 2, 3, 4, 5, 6, 7, 8]) # Positive
    ]

    passed = 0
    total = len(test_cases)

    for n_val, arr_vals in test_cases:
        dut._log.info(f"Testing n={n_val}, arr={arr_vals}")
        
        # Load inputs
        for i in range(8):
            val = arr_vals[i] if i < n_val else 0
            setattr(dut, f'a[{i}]', val)
        
        dut.n.value = n_val
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 100
        for _ in range(timeout):
            if dut.done.value == 1:
                break
            await RisingEdge(dut.clk)
        
        # Check result
        expected = calculate_expected(n_val, arr_vals)
        received = int(dut.min_dist.value)
        
        if received == expected:
            dut._log.info(f"PASS: Expected {expected}, Got {received}")
            passed += 1
        else:
            dut._log.error(f"FAIL: Expected {expected}, Got {received}")

    dut._log.info(f"
Summary: {passed}/{total} tests passed")
    assert passed == total, "Some tests failed"

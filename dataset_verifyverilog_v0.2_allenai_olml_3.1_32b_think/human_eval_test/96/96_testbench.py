import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge
from cocotb.result import TestFailure

primes_under_64 = [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53, 59, 61]

@cocotb.test()
async def test_count_up_to(dut):
    """Test count_up_to module for various inputs"""
    
    # Test cases: (input_n, expected_count, expected_primes_list)
    test_cases = [
        (0, 0, []),
        (1, 0, []),
        (2, 0, []),
        (3, 1, [2]),
        (5, 2, [2, 3]),
        (6, 3, [2, 3, 5]),
        (7, 3, [2, 3, 5]),
        (10, 4, [2, 3, 5, 7]),
        (11, 4, [2, 3, 5, 7]),
        (12, 5, [2, 3, 5, 7, 11]),
        (20, 8, [2, 3, 5, 7, 11, 13, 17, 19]),
        (22, 8, [2, 3, 5, 7, 11, 13, 17, 19]),
        (62, 18, primes_under_64),
        (63, 18, primes_under_64),
        (64, 18, primes_under_64), # Saturates/Handles max
    ]

    for n_val, expected_count, expected_primes in test_cases:
        # Set input
        dut.n.value = n_val
        
        # Wait a small amount of time for combinational logic to settle
        await Timer(10, units='ns')
        
        # Check count
        actual_count = int(dut.count.value)
        if actual_count != expected_count:
            raise TestFailure(f"Input n={n_val}: Expected count {expected_count}, got {actual_count}")
        
        # Check primes array
        for i in range(expected_count):
            expected_prime = expected_primes[i]
            actual_prime = int(dut.primes[i].value)
            if actual_prime != expected_prime:
                raise TestFailure(f"Input n={n_val}: At index {i}, expected {expected_prime}, got {actual_prime}")
        
        # Check that unused slots are 0 (optional but good practice)
        for i in range(expected_count, 18):
            val = int(dut.primes[i].value)
            if val != 0:
                 # Only fail if it's strictly wrong. Some implementations might leave garbage.
                 # We will enforce 0 for cleanliness.
                 raise TestFailure(f"Input n={n_val}: At unused index {i}, expected 0, got {val}")

    dut._log.info("All tests passed!")
}
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge
import random

@cocotb.test()
async def test_slime_game(dut):
    """Test slime game with various inputs"""
    
    # Test cases: (n, expected_count, expected_values)
    test_cases = [
        (1, 1, [1]),
        (2, 1, [2]),
        (3, 2, [2, 1]),
        (8, 1, [4]),
        (100000, 6, [17, 16, 11, 10, 8, 6]),
        (12345, 6, [14, 13, 6, 5, 4, 1]),
        (32, 1, [6]),
        (70958, 8, [17, 13, 11, 9, 6, 4, 3, 2]),
        (256, 1, [9]),
        (4096, 1, [13]),
        (33301, 5, [16, 10, 5, 3, 1]),
        (149, 4, [8, 5, 3, 1]),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for n, expected_count, expected_values in test_cases:
        # Set input
        dut.n.value = n
        
        # Wait for combinational logic to settle
        await Timer(10, units='ns')
        
        # Read outputs
        actual_count = int(dut.count.value)
        actual_values = []
        for i in range(actual_count):
            actual_values.append(int(dut.values[i].value))
        
        # Check count
        if actual_count != expected_count:
            print(f"FAIL: n={n}, expected count={expected_count}, got {actual_count}")
            continue
        
        # Check values
        if actual_values != expected_values:
            print(f"FAIL: n={n}, expected {expected_values}, got {actual_values}")
            continue
        
        print(f"PASS: n={n} -> count={actual_count}, values={actual_values}")
        passed += 1
    
    print(f"
=== Summary: {passed}/{total} tests passed ===")
    assert passed == total, f"Only {passed}/{total} tests passed"

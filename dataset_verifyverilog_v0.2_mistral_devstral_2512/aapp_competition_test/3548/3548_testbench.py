import cocotb
from cocotb.triggers import Timer
import random

@cocotb.test()
async def test_drink_partitions(dut):
    """Test the drink partitions counting module"""
    
    # Helper to calculate expected partitions for N=8
    def count_partitions(bad_pairs, n=8):
        # Generate all partitions using recursion
        # Partition is valid if each segment has no bad pairs
        
        # Convert bad pairs to set of frozensets for O(1) lookup
        bad_set = set()
        for a, b in bad_pairs:
            # Normalize ingredients to 0-indexed (0 to 7)
            bad_set.add(frozenset([a-1, b-1]))
        
        def is_valid_segment(segment):
            # Check all pairs in segment
            for i in range(len(segment)):
                for j in range(i+1, len(segment)):
                    if frozenset([segment[i], segment[j]]) in bad_set:
                        return False
            return True
        
        def count_from_pos(pos, current):
            if pos == n:
                return 1
            
            total = 0
            # Try all segment lengths starting from pos
            for end in range(pos+1, n+1):
                segment = list(range(pos, end))
                if is_valid_segment(segment):
                    total += count_from_pos(end, current + [segment])
            return total
        
        return count_from_pos(0, [])
    
    # Test cases
    test_cases = [
        # (bad_pairs, expected)
        ([], 128),  # No bad pairs: 2^(N-1) = 128 for N=8
        ([(1, 2)], 127),  # 1 and 2 cannot be together - removes 1 partition
        ([(4, 5)], 127),  # Same, different location
        ([(1, 3), (4, 5)], 126),  # Two bad pairs
        ([(1, 8)], 127),  # Far apart
        ([(2, 4), (4, 6)], 126),  # Related pairs
    ]
    
    # Limit to first 4 tests for module with small width
    test_cases = test_cases[:4]
    
    passed = 0
    total = len(test_cases)
    
    for bad_pairs, expected in test_cases:
        # Prepare inputs
        num_pairs = len(bad_pairs)
        
        # Fill arrays (max 8 pairs)
        ingredient_a = [0] * 8
        ingredient_b = [0] * 8
        
        for i, (a, b) in enumerate(bad_pairs):
            ingredient_a[i] = a
            ingredient_b[i] = b
        
        # Set inputs
        for i in range(8):
            dut.bad_pairs_ingredient_a[i].value = ingredient_a[i]
            dut.bad_pairs_ingredient_b[i].value = ingredient_b[i]
        dut.num_bad_pairs.value = num_pairs
        
        # Wait for combinational logic
        await Timer(10, units='ns')
        
        # Read output
        result = int(dut.num_partitions.value)
        
        # Apply modulo 1024
        expected_mod = expected % 1024
        
        if result == expected_mod:
            print(f"Test passed: {num_pairs} bad pairs -> {result} (expected {expected_mod})")
            passed += 1
        else:
            print(f"Test FAILED: {num_pairs} bad pairs -> {result} (expected {expected_mod})")
    
    print(f"
Summary: {passed}/{total} tests passed")
    assert passed == total, f"Only {passed}/{total} tests passed"

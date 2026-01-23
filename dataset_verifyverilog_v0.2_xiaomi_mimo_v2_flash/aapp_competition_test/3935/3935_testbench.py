import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure
import random

def count_trailing_zeros(n):
    if n == 0:
        return 64 # Arbitrary max for 64-bit
    count = 0
    while (n & 1) == 0:
        n >>= 1
        count += 1
    return count

def get_expected(numbers, valid_mask):
    counts = {}
    valid_indices = [i for i in range(16) if (valid_mask >> i) & 1]
    
    # Calculate CTZ for valid inputs
    ctz_values = {}
    for i in valid_indices:
        val = numbers[i]
        ctz = count_trailing_zeros(val)
        ctz_values[i] = ctz
        if ctz not in counts:
            counts[ctz] = 0
        counts[ctz] += 1
    
    if not counts:
        return 0, [0]*16
        
    # Find max count
    max_ctz = max(counts, key=counts.get)
    
    # Determine remove mask and values
    remove_mask = 0
    removed_values = [0]*16
    for i in valid_indices:
        if ctz_values[i] != max_ctz:
            remove_mask |= (1 << i)
            removed_values[i] = numbers[i]
            
    return remove_mask, removed_values

@cocotb.test()
def test_bipartite_set_optimizer(dut):
    # Generate 5 test cases
    for _ in range(5):
        # Setup inputs
        valid_mask = 0
        numbers_in = [0] * 16
        
        # Randomize valid inputs (1 to 16 valid items)
        num_valid = random.randint(4, 12)
        indices = random.sample(range(16), num_valid)
        for idx in indices:
            valid_mask |= (1 << idx)
            # Generate numbers with varying CTZ
            # Random base number up to 2^20
            base = random.randint(1, 2**20)
            # Random shift (0 to 10) to create trailing zeros
            shift = random.randint(0, 10)
            numbers_in[idx] = base << shift
        
        # Assign to DUT
        dut.valid_in.value = valid_mask
        for i in range(16):
            dut.numbers_in[i].value = numbers_in[i]
        
        # Wait for combinational logic
        await Timer(10, units='ns')
        
        # Check outputs
        expected_mask, expected_values = get_expected(numbers_in, valid_mask)
        
        actual_mask = int(dut.remove_mask.value)
        
        if actual_mask != expected_mask:
            print(f"Test Failed: Inputs={numbers_in}, Valid={bin(valid_mask)}")
            print(f"Expected Mask: {bin(expected_mask)}, Actual: {bin(actual_mask)}")
            raise TestFailure(f"Mask mismatch. Expected {expected_mask}, got {actual_mask}")
            
        # Check values
        for i in range(16):
            actual_val = int(dut.removed_values[i].value)
            expected_val = expected_values[i]
            if actual_val != expected_val:
                 print(f"Value mismatch at index {i}: Expected {expected_val}, Got {actual_val}")
                 raise TestFailure(f"Value mismatch at index {i}")
                 
    print("All 5 tests passed")
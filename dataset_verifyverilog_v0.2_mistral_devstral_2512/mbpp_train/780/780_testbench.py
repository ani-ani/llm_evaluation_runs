import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

def tuple_to_fixed(val):
    """Convert Python int to 8-bit representation (same as input)"""
    if val < 0 or val > 255:
        raise ValueError(f"Value {val} out of 8-bit range [0,255]")
    return val

def compute_expected(tuples):
    """Compute expected sums for all pairs"""
    from itertools import combinations
    result = []
    for (a1, a2), (b1, b2) in combinations(tuples, 2):
        result.append((a1 + b1, a2 + b2))
    return result

def verify_combination(dut, inputs, expected):
    """Verify one test case"""
    # Set inputs
    dut.tuple_0_x.value = tuple_to_fixed(inputs[0][0])
    dut.tuple_0_y.value = tuple_to_fixed(inputs[0][1])
    dut.tuple_1_x.value = tuple_to_fixed(inputs[1][0])
    dut.tuple_1_y.value = tuple_to_fixed(inputs[1][1])
    dut.tuple_2_x.value = tuple_to_fixed(inputs[2][0])
    dut.tuple_2_y.value = tuple_to_fixed(inputs[2][1])
    dut.tuple_3_x.value = tuple_to_fixed(inputs[3][0])
    dut.tuple_3_y.value = tuple_to_fixed(inputs[3][1])
    
    # Combinational - wait a bit for propagation
    yield Timer(10, units='ns')
    
    # Read outputs
    outputs = [
        (int(dut.sum_0_1_x), int(dut.sum_0_1_y)),
        (int(dut.sum_0_2_x), int(dut.sum_0_2_y)),
        (int(dut.sum_0_3_x), int(dut.sum_0_3_y)),
        (int(dut.sum_1_2_x), int(dut.sum_1_2_y)),
        (int(dut.sum_1_3_x), int(dut.sum_1_3_y)),
        (int(dut.sum_2_3_x), int(dut.sum_2_3_y))
    ]
    
    # Verify
    if outputs != expected:
        raise TestFailure(
            f"Mismatch!
Inputs: {inputs}
Expected: {expected}
Got: {outputs}"
        )
    
    dut._log.info(f"Test passed for inputs {inputs}")

@cocotb.test()
async def test_tuple_combinations(dut):
    """Test tuple combination sum calculation"""
    
    # Test 1: Original test case
    inputs1 = [(2, 4), (6, 7), (5, 1), (6, 10)]
    expected1 = [(8, 11), (7, 5), (8, 14), (11, 8), (12, 17), (11, 11)]
    await verify_combination(dut, inputs1, expected1)
    
    # Test 2
    inputs2 = [(3, 5), (7, 8), (6, 2), (7, 11)]
    expected2 = [(10, 13), (9, 7), (10, 16), (13, 10), (14, 19), (13, 13)]
    await verify_combination(dut, inputs2, expected2)
    
    # Test 3
    inputs3 = [(4, 6), (8, 9), (7, 3), (8, 12)]
    expected3 = [(12, 15), (11, 9), (12, 18), (15, 12), (16, 21), (15, 15)]
    await verify_combination(dut, inputs3, expected3)
    
    # Edge cases
    # Test 4: Zeros
    inputs4 = [(0, 0), (0, 0), (0, 0), (0, 0)]
    expected4 = [(0, 0), (0, 0), (0, 0), (0, 0), (0, 0), (0, 0)]
    await verify_combination(dut, inputs4, expected4)
    
    # Test 5: Maximum values
    inputs5 = [(100, 50), (50, 100), (75, 75), (25, 25)]
    expected5 = [(150, 150), (175, 125), (125, 75), (125, 175), (75, 125), (100, 100)]
    await verify_combination(dut, inputs5, expected5)
    
    # Test 6: Powers of 2
    inputs6 = [(1, 2), (4, 8), (16, 32), (64, 128)]
    expected6 = [(5, 10), (17, 34), (65, 130), (20, 40), (68, 136), (80, 160)]
    await verify_combination(dut, inputs6, expected6)
    
    dut._log.info("All tests passed!")
import cocotb
from cocotb.triggers import Timer
import ast

def normalize_tuples(tuples):
    return [tuple(sorted(t)) for t in tuples]

def gen_test_vector(test_list):
    flat = [item for t in test_list for item in t]
    return [x % 16 for x in flat]  # Constrain to 4 bits

def expected_mask(list1, list2):
    norm1 = set(normalize_tuples(list1))
    norm2 = set(normalize_tuples(list2))
    return [int(tuple(sorted(t)) in norm2) for t in list1][:4]

@cocotb.test()
async def test_intersection(dut):
    tests = [
        ([(3,4), (5,6), (9,10), (4,5)], [(5,4), (3,4), (6,5), (9,11)]),
        ([(4,1), (7,4), (11,13), (17,14)], [(1,4), (7,4), (16,12), (10,13)]),  # 17 capped to 1 (17%16=1)
        ([(2,1), (3,2), (1,3), (1,4)], [(11,2), (2,3), (6,2), (1,3)])
    ]
    passed = 0
    for list1, list2 in tests:
        # Adapt inputs to 4 bits
        list1_adapted = [(a%16, b%16) for a,b in list1[:4]]
        list2_adapted = [(a%16, b%16) for a,b in list2[:4]]
        
        # Generate test vector
        list1_vec = gen_test_vector(list1_adapted)
        list2_vec = gen_test_vector(list2_adapted)
        
        # Apply inputs
        for i, val in enumerate(list1_vec):
            getattr(dut, f"list1_{i}").value = val
        for i, val in enumerate(list2_vec):
            getattr(dut, f"list2_{i}").value = val
            
        await Timer(1, 'ns')
        
        # Calculate expected result
        expected = expected_mask(list1_adapted, list2_adapted)
        mask = [int(b) for b in dut.mask.value.binstr[::-1][:4]]
        
        if mask == expected:
            passed += 1
            dut._log.info(f"PASS: Mask {mask} == {expected}")
        else:
            dut._log.error(f"FAIL: Input1 {list1_adapted} | Input2 {list2_adapted}")
            dut._log.error(f"  Expected mask {expected}, got {mask}")
    
    dut._log.info(f"{passed}/{len(tests)} tests passed")
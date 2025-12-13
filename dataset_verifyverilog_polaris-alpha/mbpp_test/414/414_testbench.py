import cocotb
from cocotb.triggers import Timer
from cocotb.types import LogicArray

@cocotb.test()
async def test_overlap(dut):
    test_cases = [
        # Test 1 (Original Test 1)
        ([1,2,3,4,5,0,0,0], [6,7,8,9,0,0,0,0], False),
        # Test 2 (Original Test 2)
        ([1,2,3,0,0,0,0,0], [4,5,6,0,0,0,0,0], False),
        # Test 3 (Original Test 3)
        ([1,4,5,0,0,0,0,0], [1,4,5,0,0,0,0,0], True),
        # Additional edge case 1 (empty lists)
        ([0,0,0,0,0,0,0,0], [0,0,0,0,0,0,0,0], True),
        # Additional edge case 2 (max element match)
        ([15,0,0,0,0,0,0,0], [10,15,0,0,0,0,0,0], True)
    ]
    
    passed = 0
    for i, (lst1, lst2, expected) in enumerate(test_cases):
        # Pad lists to 8 elements
        padded_lst1 = lst1 + [0]*(8-len(lst1))
        padded_lst2 = lst2 + [0]*(8-len(lst2))
        
        # Set inputs
        dut.list1.value = LogicArray(padded_lst1)
        dut.list2.value = LogicArray(padded_lst2)
        
        await Timer(1, units='ns')
        
        actual = dut.overlap.value
        if actual == expected:
            passed += 1
            dut._log.info(f"Test {i+1} PASS: {lst1} & {lst2} => {actual}")
        else:
            dut._log.error(f"Test {i+1} FAIL: {lst1} & {lst2} => {actual}, expected {expected}")
    
    dut._log.info(f"Summary: {passed}/{len(test_cases)} tests passed")
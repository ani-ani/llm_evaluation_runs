import cocotb
from cocotb.triggers import Timer
from cocotb.types import LogicArray

@cocotb.test()
async def test_filter(dut):
    test_cases = [
        # Original Test 1 (trimmed to first 8 elements)
        {
            "input": [1,2,3,4,5,6,7,8],
            "expected_nums": [1,0,3,0,5,0,7,0],
            "expected_mask": 0b10101010
        },
        # Test 2 (padded to 8 with even zeros)
        {
            "input": [10,20,45,67,84,93,0,0],
            "expected_nums": [0,0,45,67,0,93,0,0],  # Maintain positions
            "expected_mask": 0b00110100
        },
        # Edge cases
        {
            "input": [0,0,0,0,0,0,0,0],
            "expected_nums": [0,0,0,0,0,0,0,0],
            "expected_mask": 0b00000000
        },
        {
            "input": [255,1,3,5,7,9,11,13],  # All odd
            "expected_nums": [255,1,3,5,7,9,11,13],
            "expected_mask": 0b11111111
        }
    ]
    
    passed = 0
    for case in test_cases:
        # Apply inputs
        for i in range(8):
            dut.nums[i].value = case["input"][i]
        
        await Timer(1, units='ns')
        
        # Check output numbers
        num_errors = 0
        for i in range(8):
            actual = dut.filtered_nums[i].value
            expected = case["expected_nums"][i]
            if actual != expected:
                dut._log.error(f"Index {i}: Got {actual}, expected {expected}")
                num_errors += 1
        
        # Check valid mask
        mask_actual = dut.valid_mask.value
        mask_expected = case["expected_mask"]
        if mask_actual != mask_expected:
            dut._log.error(f"Mask error: Got {bin(mask_actual)}, expected {bin(mask_expected)}")
            num_errors += 1
        
        if num_errors == 0:
            passed += 1
            dut._log.info(f"Passed case: {case['input']}")
    
    total = len(test_cases)
    dut._log.info(f"{passed}/{total} tests passed")
    assert passed == total, "Some tests failed"
import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_element_wise_div(dut):
    # Test cases in Q8.8 format (decimal_value * 256)
    test_cases = [
        # Test 1: [4,5,6]/[1,2,3] -> [4.0, 2.5, 2.0]
        {"nums1": [4,5,6,0], "nums2": [1,2,3,1], "expected": [4*256, int(2.5*256), int(2.0*256), 0]},
        # Test 2: [3,2]/[1,4] -> [3.0, 0.5]
        {"nums1": [3,2,0,0], "nums2": [1,4,1,1], "expected": [3*256, int(0.5*256), 0, 0]},
        # Test 3: [90,120]/[50,70] 
        {"nums1": [90,120,0,0], "nums2": [50,70,1,1], "expected": [int(1.8*256), int(1.714285*256), 0, 0]},
        # Edge case: Max value test
        {"nums1": [255,255,255,255], "nums2": [1,1,1,1], "expected": [255*256]*4}
    ]

    passed = 0
    for case in test_cases:
        dut.nums1.value = cocotb.binary.BinaryValue(value=bytes(case["nums1"]), n_bits=32)
        dut.nums2.value = cocotb.binary.BinaryValue(value=bytes(case["nums2"]), n_bits=32)
        await Timer(1, units='ns')  # Allow combinational logic
        
        actual = dut.result.value.buff
        expected_bytes = bytes([(x >> 8) & 0xFF for x in case["expected"]] +
                              [x & 0xFF for x in case["expected"]])
        
        if actual == expected_bytes:
            passed += 1
            dut._log.info(f"PASS: {case['nums1']}/{case['nums2']}")
        else:
            dut._log.error(f"FAIL:
  Inputs1: {case['nums1']}
  Inputs2: {case['nums2']}
  Expected: {[f'{x/256:.2f}' for x in case['expected']]}
  Actual: {[x/256 for x in int.from_bytes(actual,'big').to_bytes(8,'big')]}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
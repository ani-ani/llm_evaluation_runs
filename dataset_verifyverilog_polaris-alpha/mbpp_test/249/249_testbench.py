import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_intersection(dut):
    test_cases = [
        {
            "len1": 8, "array1": [1,2,3,5,7,8,9,10], "len2":5, "array2": [1,2,4,8,9,0,0,0],
            "expected": [1,2,8,9], "expected_len":4
        },
        {
            "len1":8, "array1": [1,2,3,5,7,8,9,10], "len2":4, "array2": [3,5,7,9,0,0,0,0],
            "expected": [3,5,7,9], "expected_len":4
        },
        {
            "len1":8, "array1": [1,2,3,5,7,8,9,10], "len2":4, "array2": [10,20,30,40,0,0,0,0],
            "expected": [10], "expected_len":1
        },
        {
            "len1":3, "array1": [1,1,1,0,0,0,0,0], "len2":2, "array2": [1,1,0,0,0,0,0,0],
            "expected": [1,1], "expected_len":2
        },
        {
            "len1":3, "array1": [2,3,4,0,0,0,0,0], "len2":2, "array2": [5,6,0,0,0,0,0,0],
            "expected": [], "expected_len":0
        }
    ]
    passed = 0
    for tc in test_cases:
        dut.len1.value = tc["len1"]
        dut.len2.value = tc["len2"]
        for i in range(8):
            dut.array1[i].value = tc["array1"][i]
            dut.array2[i].value = tc["array2"][i]
        await Timer(1, units="ns")
        actual_len = dut.result_len.value
        if actual_len != tc["expected_len"]:
            dut._log.error(f"Test failed: Expected len {tc['expected_len']}, got {actual_len}. Test case: {tc}")
        else:
            valid = True
            for i in range(actual_len):
                if dut.result[i].value != tc["expected"][i]:
                    dut._log.error(f"Mismatch at index {i}: Expected {tc['expected'][i]}, got {int(dut.result[i].value)}")
                    valid = False
            if valid:
                passed +=1
                dut._log.info(f"Test passed for input: {tc['array2'][:tc['len2']]} with array1 {tc['array1'][:tc['len1']]}")
            else:
                dut._log.error(f"Test failed: Output mismatch. Test case: {tc}")
    dut._log.info(f"Test summary: {passed}/{len(test_cases)} passed")
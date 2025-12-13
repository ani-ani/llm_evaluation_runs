import cocotb
from cocotb.triggers import Timer
from cocotb.types import LogicArray, Range

@cocotb.test()
async def test_array_range_sum(dut):
    # Helper function to pack list into 128-bit value
    def pack_array(arr):
        padded = arr + [0]*(16-len(arr))
        val = 0
        for i, elem in enumerate(padded):
            val |= (elem & 0xFF) << (i*8)
        return val
    
    # Original test cases adapted to 16-element array
    test_cases = [
        {"array": [2,1,5,6,8,3,4,9,10,11,8,12], "m": 8, "n":10, "expected":29},  # Original Test1
        {"array": [2,1,5,6,8,3,4,9,10,11,8,12], "m":5, "n":7, "expected":16},   # Original Test2
        {"array": [2,1,5,6,8,3,4,9,10,11,8,12], "m":7, "n":10, "expected":38}, # Original Test3
        {"array": [255]*16, "m":0, "n":15, "expected":16*255},               # Max value test
        {"array": [10,20,30], "m":1, "n":1, "expected":20},                   # Single element
        {"array": [1,2,3,4], "m":2, "n":1, "expected":0}                     # Invalid indices
    ]
    
    passed = 0
    for case in test_cases:
        # Convert array to packed format
        packed = pack_array(case["array"])
        dut.array_data.value = packed        
        dut.start_idx.value = case["m"]
        dut.end_idx.value = case["n"]
        
        await Timer(1, units='ns')  # Combinational delay
        
        result = dut.range_sum.value.integer
        expected = case["expected"]
        
        try:
            assert result == expected, f"Array {case['array']} m={case['m']} n={case['n']}: Got {result}, expected {expected}"
            passed += 1
            dut._log.info(f"PASS: Test {test_cases.index(case)+1}")
        except AssertionError as e:
            dut._log.error(str(e))
    
    total = len(test_cases)
    dut._log.info(f"TEST SUMMARY: {passed}/{total} tests passed")
import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_max_sublist(dut):
    # Test cases: [[original values], padded to 4 inputs]
    test_cases = [
        ([1, 2, 4, 0], 4),  # Original: [[1],[1,4],[5,6,7,8]] → [1,2,4,0]
        ([2, 2, 3, 0], 3),  # Original: [[0,1],[2,2,],[3,2,1]] → [2,2,3,0]
        ([1, 2, 3, 5], 5),  # Original: [[7],[22,23],[13,14,15],[10,20,30,40,50]]
        ([0, 0, 0, 0], 0),  # Edge case: all empty
        ([7, 3, 5, 2], 7)   # Edge case: max first element
    ]
    
    passed = 0
    for lengths, expected in test_cases:
        dut.length1.value = lengths[0]
        dut.length2.value = lengths[1]
        dut.length3.value = lengths[2]
        dut.length4.value = lengths[3]
        await Timer(1, units='ns')
        
        if dut.max_length.value == expected:
            dut._log.info(f"PASS: Inputs {lengths} → {dut.max_length.value}")
            passed += 1
        else:
            dut._log.error(f"FAIL: Inputs {lengths} → {dut.max_length.value}, expected {expected}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    if passed != len(test_cases):
        raise TestFailure("Some tests failed")
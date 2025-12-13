import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_k_pairs(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    async def reset():
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        await Timer(10, units='ns')
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    test_cases = [
        # Test 1 (Original Test 1)
        {'nums1': [1,3,7]+[0]*5, 'size1':3,
         'nums2': [2,4,6]+[0]*5, 'size2':3,
         'k':2, 'expected': [[1,2],[1,4]]},
        
        # Test 2 (Original Test 2)
        {'nums1': [1,3,7]+[0]*5, 'size1':3,
         'nums2': [2,4,6]+[0]*5, 'size2':3,
         'k':1, 'expected': [[1,2]]},
        
        # Test 3 (Scaled Original Test 3)
        {'nums1': [1,3,7]+[0]*5, 'size1':3,
         'nums2': [2,4,6]+[0]*5, 'size2':3,
         'k':7, 'expected': [[1,2],[1,4],[3,2],[1,6],[3,4],[3,6],[7,2]]},
        
        # Edge case: k larger than possible pairs
        {'nums1': [5]+[0]*7, 'size1':1,
         'nums2': [3]+[0]*7, 'size2':1,
         'k':4, 'expected': [[5,3]]}
    ]
    
    await reset()
    passed = 0
    
    for case in test_cases:
        # Load inputs
        for i in range(8):
            dut.nums1[i].value = case['nums1'][i]
            dut.nums2[i].value = case['nums2'][i]
        dut.array1_size.value = case['size1']
        dut.array2_size.value = case['size2']
        dut.k.value = case['k']
        
        # Wait for computation
        for _ in range(12):
            await RisingEdge(dut.clk)
        
        # Check valid
        if dut.valid.value != 1:
            dut._log.error(f"VALID not asserted after 12 cycles")
            continue
        
        # Compare outputs
        failed = False
        expected = [[0,0]] * 16
        actual_len = min(case['k'], case['size1']*case['size2'])
        for i in range(actual_len):
            expected[i] = case['expected'][i]
        
        for i in range(16):
            pair_actual = [dut.pairs[i][0].value, dut.pairs[i][1].value]
            pair_expected = expected[i]
            
            if list(pair_actual) != pair_expected:
                failed = True
                dut._log.error(f"FAIL Test {case}:
"
                               f"Pair {i}: got {pair_actual}, expected {pair_expected}")
        
        if not failed:
            passed += 1
            dut._log.info(f"PASS Test: {case['expected'][0:actual_len]}")
    
    total = len(test_cases)
    dut._log.info(f"RESULTS: {passed}/{total} tests passed")
    assert passed == total
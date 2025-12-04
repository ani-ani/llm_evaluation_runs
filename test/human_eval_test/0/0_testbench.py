import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_close_elements(dut):
    def float_to_q8_8(f):
        return int(f * 256)
    
    test_cases = [
        # Format: ([numbers], threshold, expected)
        # Original: [1.0, 2.0, 3.0], 0.5 → False
        ([1.0, 2.0, 3.0]+[0]*5, 0.5, False),
        
        # Original: [1.0, 2.8, 3.0, 4.0, 5.0, 2.0], 0.3 → True
        ([1.0, 2.8, 3.0, 4.0, 5.0, 2.0]+[0]*2, 0.3, True),
        
        # Edge case: exact elements
        ([1.0, 2.0, 2.0]+[0]*5, 0.0, True),
        
        # Original: [1.1, 2.2, 3.1, 4.1, 5.1], 0.5 → False
        ([1.1, 2.2, 3.1, 4.1, 5.1]+[0]*3, 0.5, False),
        
        # Max separation test
        ([10.0, 20.0]+[0]*6, 9.9, True)  # 10.0 and 20.0 differ by 10.0
    ]
    
    passed = 0
    for numbers, threshold, expected in test_cases:
        # Pack numbers into 128-bit bus (8x16b)
        packed = 0
        for i, num in enumerate(numbers):
            q_val = float_to_q8_8(num)
            packed |= q_val << (i*16)
        
        dut.numbers_packed.value = packed
        dut.threshold_q8_8.value = float_to_q8_8(threshold)
        
        await Timer(1, units='ns')  # combinational delay
        
        result = dut.has_close_pair.value
        if result == expected:
            passed += 1
            dut._log.info(f"PASS: {numbers} ({hex(packed)}) thr={threshold} → {expected}")
        else:
            dut._log.error(f"FAIL: {numbers} thr={threshold} got {result}, expected {expected}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
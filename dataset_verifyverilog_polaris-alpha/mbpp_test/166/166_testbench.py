import cocotb
from cocotb.triggers import Timer
@cocotb.test()
async def test_even_xor(dut):
    test_cases = [
        # Original test 1 (5 elements)
        ([5,4,7,2,1], 4),
        # Original test 2 (7 elements)
        ([7,2,8,1,0,5,11], 9),
        # Original test 3 (3 elements)
        ([1,2,3], 1),
        # Edge case: all even
        ([2,4,6,0,0,0,0,0], 6),
        # Edge case: empty pairs
        ([0,0,0,0,0,0,0,0], 0)
    ]
    passed = 0
    for vec, expected in test_cases:
        vec_padded = vec + [0]*(8-len(vec))  # Pad to 8 elements
        
        # Assign inputs
        for i, val in enumerate(vec_padded):
            getattr(dut, f"a{i}").value = val
            
        await Timer(1, units='ns')
        actual = dut.count.value
        
        if actual == expected:
            passed += 1
            dut._log.info(f"PASS: {vec} => count={actual}")
        else:
            dut._log.error(f"FAIL: {vec} => got {actual}, expected {expected}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
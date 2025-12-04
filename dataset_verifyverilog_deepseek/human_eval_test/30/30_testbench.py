import cocotb
from cocotb.triggers import Timer
from cocotb.types import LogicArray

@cocotb.test()
async def test_filter(dut):
    """Test cases scaled to 16-element arrays"""
    test_cases = [
        # Test case 1 (original
        ([-1,-2,4,5,6] + [0]*11, [4,5,6] + [0]*13, 0b0000000000000111),
        # Test case 2 (original
        ([5,3,-5,2,3,3,9,0,123,1,-10] + [0]*5, [5,3,2,3,3,9,123,1] + [0]*8, 0b1111111100000000),
        # Test case 3 (original
        ([-1,-2] + [0]*14, [0]*16, 0b0000000000000000),
        # Test case 4 (original)
        ([192, -128] + [0]*14, [192] + [0]*15, 0b0000000000000001)
    ]
    passed = 0
    
    for (array_in, expected_out, expected_mask) in test_cases:
        # Apply inputs
        for i in range(16):
            dut.array_in[i].value = array_in[i]
        
        await Timer(1, units='ns')
        
        # Collect outputs
        filtered_out = [int(dut.filtered_out[i].value) for i in range(16)]
        valid_mask = int(dut.valid_mask.value)
        
        # Validate outputs
        passed_test = True
        if filtered_out != expected_out:
            dut._log.error(f"Output mismatch:\GOT      {filtered_out}
EXPECTED {expected_out}")
            passed_test = False
        if valid_mask != expected_mask:
            dut._log.error(f"Mask mismatch: Got {valid_mask:016b}, Expected {expected_mask:016b}")
            passed_test = False
        
        if passed_test:
            passed +=1
            dut._log.info(f"Passed test case: {array_in}")
        else:
            dut._log.error(f"Failed test case: {array_in}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
import cocotb
from cocotb.triggers import Timer
import random

@cocotb.test()
async def test_intersperse(dut):
    """ Test intersperse functionality with fixed-size inputs """
    
    # Test cases: (input_array, delimiter, expected_output)
    test_cases = [
        ([], 7, []),
        ([5, 6, 3, 2], 8, [5, 8, 6, 8, 3, 8, 2]),
        ([2, 2, 2], 2, [2, 2, 2, 2, 2])
    ]
    
    for i, (input_list, delim, expected) in enumerate(test_cases):
        dut._log.info(f"Test case {i+1}: Input={input_list}, Delimiter={delim}")
        
        # Set inputs
        dut.in_valid.value = len(input_list)
        dut.delimiter.value = delim
        
        # Initialize all input elements to 0
        for idx in range(4):
            dut.in_data[idx].value = 0
            
        # Set specific input elements
        for idx, val in enumerate(input_list):
            dut.in_data[idx].value = val
            
        # Wait for combinational logic to settle
        await Timer(1, units='ns')
        
        # Read outputs
        out_valid = int(dut.out_valid.value)
        out_data = []
        for idx in range(8):
            val = int(dut.out_data[idx].value)
            if idx < out_valid:
                out_data.append(val)
                
        # Verify
        expected_valid = len(expected)
        assert out_valid == expected_valid, f"Valid mismatch: got {out_valid}, expected {expected_valid}"
        assert out_data == expected, f"Data mismatch: got {out_data}, expected {expected}"
        
    dut._log.info("All tests passed!")
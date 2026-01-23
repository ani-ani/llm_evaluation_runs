import cocotb
from cocotb.triggers import Timer
import random

@cocotb.test()
async def test_pairwise_mult(dut):
    """Test pairwise multiplication of 8 elements"""
    
    # Test Case 1: From original problem (scaled down to fit 8 elements, max value 255)
    # Original: (1, 5, 7, 8, 10) -> (5, 35, 56, 80)
    # Scaled Input: [1, 5, 7, 8, 10, 0, 0, 0]
    dut.data_in[0].value = 1
    dut.data_in[1].value = 5
    dut.data_in[2].value = 7
    dut.data_in[3].value = 8
    dut.data_in[4].value = 10
    dut.data_in[5].value = 0
    dut.data_in[6].value = 0
    dut.data_in[7].value = 0
    
    await Timer(10, units='ns')
    
    assert dut.data_out[0].value == 1 * 5, f"Test 1 Failed: Expected {1*5}, Got {int(dut.data_out[0].value)}"
    assert dut.data_out[1].value == 5 * 7, f"Test 1 Failed: Expected {5*7}, Got {int(dut.data_out[1].value)}"
    assert dut.data_out[2].value == 7 * 8, f"Test 1 Failed: Expected {7*8}, Got {int(dut.data_out[2].value)}"
    assert dut.data_out[3].value == 8 * 10, f"Test 1 Failed: Expected {8*10}, Got {int(dut.data_out[3].value)}"
    assert dut.data_out[4].value == 10 * 0, f"Test 1 Failed: Expected {10*0}, Got {int(dut.data_out[4].value)}"
    assert dut.data_out[5].value == 0 * 0, f"Test 1 Failed: Expected {0*0}, Got {int(dut.data_out[5].value)}"
    assert dut.data_out[6].value == 0 * 0, f"Test 1 Failed: Expected {0*0}, Got {int(dut.data_out[6].value)}"
    
    print("Test Case 1 Passed")

    # Test Case 2: Random data
    input_vals = [random.randint(0, 255) for _ in range(8)]
    for i in range(8):
        dut.data_in[i].value = input_vals[i]
    
    await Timer(10, units='ns')
    
    for i in range(7):
        expected = input_vals[i] * input_vals[i+1]
        actual = int(dut.data_out[i].value)
        assert actual == expected, f"Random Test Failed at index {i}: Expected {expected}, Got {actual}"
        
    print("Test Case 2 Passed")

    # Test Case 3: Max values
    for i in range(8):
        dut.data_in[i].value = 255
    
    await Timer(10, units='ns')
    
    for i in range(7):
        assert int(dut.data_out[i].value) == 65025, f"Max Value Test Failed at index {i}"
        
    print("Test Case 3 Passed")
    print(f"Summary: 3/3 tests passed")
import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_poly_derivative(dut):
    # Test Case 1: [3, 1, 2, 4, 5] -> [1, 4, 12, 20]
    dut.num_coeffs.value = 5
    dut.xs[0].value = 3
    dut.xs[1].value = 1
    dut.xs[2].value = 2
    dut.xs[3].value = 4
    dut.xs[4].value = 5
    # Wait for combinational logic
    await Timer(1, units='ns')
    
    assert dut.deriv_len.value == 4, f"Expected length 4, got {dut.deriv_len.value}"
    assert dut.deriv[0].value == 1, f"Expected 1, got {dut.deriv[0].value}"
    assert dut.deriv[1].value == 4, f"Expected 4, got {dut.deriv[1].value}"
    assert dut.deriv[2].value == 12, f"Expected 12, got {dut.deriv[2].value}"
    assert dut.deriv[3].value == 20, f"Expected 20, got {dut.deriv[3].value}"
    print("Test 1 Passed")

    # Test Case 2: [1, 2, 3] -> [2, 6]
    dut.num_coeffs.value = 3
    dut.xs[0].value = 1
    dut.xs[1].value = 2
    dut.xs[2].value = 3
    await Timer(1, units='ns')
    
    assert dut.deriv_len.value == 2
    assert dut.deriv[0].value == 2
    assert dut.deriv[1].value == 6
    print("Test 2 Passed")

    # Test Case 3: [3, 2, 1] -> [2, 2]
    dut.num_coeffs.value = 3
    dut.xs[0].value = 3
    dut.xs[1].value = 2
    dut.xs[2].value = 1
    await Timer(1, units='ns')
    
    assert dut.deriv_len.value == 2
    assert dut.deriv[0].value == 2
    assert dut.deriv[1].value == 2
    print("Test 3 Passed")

    # Test Case 4: [3, 2, 1, 0, 4] -> [2, 2, 0, 16]
    dut.num_coeffs.value = 5
    dut.xs[0].value = 3
    dut.xs[1].value = 2
    dut.xs[2].value = 1
    dut.xs[3].value = 0
    dut.xs[4].value = 4
    await Timer(1, units='ns')
    
    assert dut.deriv_len.value == 4
    assert dut.deriv[0].value == 2
    assert dut.deriv[1].value == 2
    assert dut.deriv[2].value == 0
    assert dut.deriv[3].value == 16
    print("Test 4 Passed")

    # Test Case 5: [1] -> []
    dut.num_coeffs.value = 1
    dut.xs[0].value = 1
    await Timer(1, units='ns')
    
    assert dut.deriv_len.value == 0
    print("Test 5 Passed")
    
    # Test Case 6: [0, 0] -> [0]
    dut.num_coeffs.value = 2
    dut.xs[0].value = 0
    dut.xs[1].value = 0
    await Timer(1, units='ns')
    
    assert dut.deriv_len.value == 1
    assert dut.deriv[0].value == 0
    print("Test 6 Passed")

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer

@cocotb.test()
async def test_extract_first(dut):
    # Initialize input array
    # The DUT expects sublists[0:3][0:7]
    # We will map the Python test cases to this structure.
    # Python Test 1: [[1, 2], [3, 4, 5], [6, 7, 8, 9]] -> [1, 3, 6]
    # We have 3 sublists. We map them to the first 3 slots of our input.
    # Slot 0: [1, 2, ...] -> sublists[0][0] = 1
    # Slot 1: [3, 4, 5, ...] -> sublists[1][0] = 3
    # Slot 2: [6, 7, 8, 9, ...] -> sublists[2][0] = 6
    # Slot 3: unused -> sublists[3][0] = 0 (default)

    dut.sublists[0][0] = 1
    dut.sublists[1][0] = 3
    dut.sublists[2][0] = 6
    dut.sublists[3][0] = 0
    
    # Wait for combinational logic to settle
    await Timer(10, units='ns')
    
    assert dut.first_elements[0].value == 1, f"Expected 1, got {dut.first_elements[0].value}"
    assert dut.first_elements[1].value == 3, f"Expected 3, got {dut.first_elements[1].value}"
    assert dut.first_elements[2].value == 6, f"Expected 6, got {dut.first_elements[2].value}"
    print("Test 1 Passed")

    # Python Test 2: [[1,2,3],[4, 5]] -> [1,4]
    dut.sublists[0][0] = 1
    dut.sublists[1][0] = 4
    dut.sublists[2][0] = 0 # Reset
    dut.sublists[3][0] = 0
    
    await Timer(10, units='ns')
    
    assert dut.first_elements[0].value == 1
    assert dut.first_elements[1].value == 4
    print("Test 2 Passed")

    # Python Test 3: [[9,8,1],[1,2]] -> [9,1]
    dut.sublists[0][0] = 9
    dut.sublists[1][0] = 1
    dut.sublists[2][0] = 0
    dut.sublists[3][0] = 0
    
    await Timer(10, units='ns')
    
    assert dut.first_elements[0].value == 9
    assert dut.first_elements[1].value == 1
    print("Test 3 Passed")
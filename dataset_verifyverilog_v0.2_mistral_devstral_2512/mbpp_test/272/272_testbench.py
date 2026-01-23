import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

def to_binary_array(values):
    """Helper to convert Python integers to binary representation"""
    return [val for val in values]

@cocotb.test()
async def test_rear_extract_basic(dut):
    """Test basic extraction with 3 tuples"""
    # Test case 1: [(1, 'Rash', 21), (2, 'Varsha', 20), (3, 'Kil', 19)]
    # Values: 1, 2, 3 for field0; 'Rash'/'Varsha'/'Kil' for field1; 21,20,19 for field2
    dut.num_tuples.value = 3
    
    # Field0: IDs
    dut.tuple_field0[0].value = 1
    dut.tuple_field0[1].value = 2
    dut.tuple_field0[2].value = 3
    dut.tuple_field0[3].value = 0
    
    # Field1: Names (first char as representation)
    dut.tuple_field1[0].value = ord('R')  # Rash
    dut.tuple_field1[1].value = ord('V')  # Varsha
    dut.tuple_field1[2].value = ord('K')  # Kil
    dut.tuple_field1[3].value = 0
    
    # Field2: Values to extract
    dut.tuple_field2[0].value = 21
    dut.tuple_field2[1].value = 20
    dut.tuple_field2[2].value = 19
    dut.tuple_field2[3].value = 0
    
    await Timer(1, units='ns')
    
    # Check outputs
    assert dut.rear_elements[0].value == 21, f"Expected 21, got {dut.rear_elements[0].value}"
    assert dut.rear_elements[1].value == 20, f"Expected 20, got {dut.rear_elements[1].value}"
    assert dut.rear_elements[2].value == 19, f"Expected 19, got {dut.rear_elements[2].value}"
    assert dut.rear_elements[3].value == 0, f"Expected 0, got {dut.rear_elements[3].value}"
    
    dut._log.info("Test 1 passed: Basic extraction")

@cocotb.test()
async def test_rear_extract_second_case(dut):
    """Test with second test case values"""
    # [(1, 'Sai', 36), (2, 'Ayesha', 25), (3, 'Salman', 45)]
    dut.num_tuples.value = 3
    
    # Field0
    dut.tuple_field0[0].value = 1
    dut.tuple_field0[1].value = 2
    dut.tuple_field0[2].value = 3
    dut.tuple_field0[3].value = 0
    
    # Field1
    dut.tuple_field1[0].value = ord('S')
    dut.tuple_field1[1].value = ord('A')
    dut.tuple_field1[2].value = ord('S')
    dut.tuple_field1[3].value = 0
    
    # Field2
    dut.tuple_field2[0].value = 36
    dut.tuple_field2[1].value = 25
    dut.tuple_field2[2].value = 45
    dut.tuple_field2[3].value = 0
    
    await Timer(1, units='ns')
    
    assert dut.rear_elements[0].value == 36
    assert dut.rear_elements[1].value == 25
    assert dut.rear_elements[2].value == 45
    assert dut.rear_elements[3].value == 0
    
    dut._log.info("Test 2 passed")

@cocotb.test()
async def test_rear_extract_single_tuple(dut):
    """Test with only 1 tuple"""
    # [(1, 'S', 100)]
    dut.num_tuples.value = 1
    
    dut.tuple_field0[0].value = 1
    dut.tuple_field1[0].value = ord('S')
    dut.tuple_field2[0].value = 100
    
    # Reset unused fields
    for i in range(1, 4):
        dut.tuple_field0[i].value = 0
        dut.tuple_field1[i].value = 0
        dut.tuple_field2[i].value = 0
    
    await Timer(1, units='ns')
    
    assert dut.rear_elements[0].value == 100
    assert dut.rear_elements[1].value == 0
    assert dut.rear_elements[2].value == 0
    assert dut.rear_elements[3].value == 0
    
    dut._log.info("Test 3 passed: Single tuple")

@cocotb.test()
async def test_rear_extract_edge_values(dut):
    """Test with boundary values (0, 255, powers of 2)"""
    # [(0, 'X', 0), (99, 'Y', 128), (255, 'Z', 255)]
    dut.num_tuples.value = 3
    
    dut.tuple_field0[0].value = 0
    dut.tuple_field0[1].value = 99
    dut.tuple_field0[2].value = 255
    dut.tuple_field0[3].value = 0
    
    dut.tuple_field1[0].value = ord('X')
    dut.tuple_field1[1].value = ord('Y')
    dut.tuple_field1[2].value = ord('Z')
    dut.tuple_field1[3].value = 0
    
    dut.tuple_field2[0].value = 0
    dut.tuple_field2[1].value = 128
    dut.tuple_field2[2].value = 255
    dut.tuple_field2[3].value = 0
    
    await Timer(1, units='ns')
    
    assert dut.rear_elements[0].value == 0
    assert dut.rear_elements[1].value == 128
    assert dut.rear_elements[2].value == 255
    assert dut.rear_elements[3].value == 0
    
    dut._log.info("Test 4 passed: Edge values")

@cocotb.test()
async def test_rear_extract_all_four(dut):
    """Test with all 4 tuples filled"""
    # [(10, 'A', 10), (20, 'B', 20), (30, 'C', 30), (40, 'D', 40)]
    dut.num_tuples.value = 4
    
    for i in range(4):
        dut.tuple_field0[i].value = (i + 1) * 10
        dut.tuple_field1[i].value = ord('A') + i
        dut.tuple_field2[i].value = (i + 1) * 10
    
    await Timer(1, units='ns')
    
    assert dut.rear_elements[0].value == 10
    assert dut.rear_elements[1].value == 20
    assert dut.rear_elements[2].value == 30
    assert dut.rear_elements[3].value == 40
    
    dut._log.info("Test 5 passed: All 4 tuples")

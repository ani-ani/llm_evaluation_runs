import cocotb
from cocotb.triggers import Timer

# Helper function to convert decimal fraction to Q16.16 fixed point
def to_q1616(value):
    return int(value * 65536)

@cocotb.test()
async def test_drink_satisfaction(dut):
    """Test the drink satisfaction module"""
    
    # Test Case 1: 3 people, mutually exclusive requirements
    # Person 0: A=1.0 (10000/10000) -> needs all A
    # Person 1: B=1.0
    # Person 2: C=1.0
    # Result: Only 1 person can be satisfied at a time
    
    print("Test Case 1: Mutually exclusive requirements")
    
    # Initialize all inputs to 0
    dut.req_A.value = 0
    dut.req_B.value = 0
    dut.req_C.value = 0
    dut.num_people.value = 3
    
    # Set Person 0
    dut.req_A[0].value = to_q1616(1.0) # 65536
    dut.req_B[0].value = 0
    dut.req_C[0].value = 0
    
    # Set Person 1
    dut.req_A[1].value = 0
    dut.req_B[1].value = to_q1616(1.0) # 65536
    dut.req_C[1].value = 0
    
    # Set Person 2
    dut.req_A[2].value = 0
    dut.req_B[2].value = 0
    dut.req_C[2].value = to_q1616(1.0) # 65536
    
    # Wait for combinational logic to settle
    await Timer(10, units='ns')
    
    result = int(dut.max_satisfied.value)
    print(f"Expected: 1, Got: {result}")
    assert result == 1, f"Test 1 failed: expected 1, got {result}"
    
    # Test Case 2: 3 people, overlapping compatible requirements
    # Person 0: A=0.5, B=0, C=0
    # Person 1: A=0, B=0.2, C=0
    # Person 2: A=0, B=0, C=0.4
    # Sum: 0.5 + 0.2 + 0.4 = 1.1 (Too much, cannot satisfy all 3)
    # Check subsets:
    # {0, 1}: 0.5 + 0.2 = 0.7 <= 1.0 (Valid)
    # {0, 2}: 0.5 + 0.4 = 0.9 <= 1.0 (Valid)
    # {1, 2}: 0.2 + 0.4 = 0.6 <= 1.0 (Valid)
    # Result: 2
    
    print("
Test Case 2: Overlapping requirements")
    
    # Reset inputs
    dut.req_A.value = 0
    dut.req_B.value = 0
    dut.req_C.value = 0
    dut.num_people.value = 3
    
    # Person 0: A=0.5
    dut.req_A[0].value = to_q1616(0.5) # 32768
    # Person 1: B=0.2
    dut.req_B[1].value = to_q1616(0.2) # 13107
    # Person 2: C=0.4
    dut.req_C[2].value = to_q1616(0.4) # 26214
    
    await Timer(10, units='ns')
    
    result = int(dut.max_satisfied.value)
    print(f"Expected: 2, Got: {result}")
    assert result == 2, f"Test 2 failed: expected 2, got {result}"
    
    # Test Case 3: 5 people, all compatible
    # Person 0: A=0.1, B=0.1, C=0.1
    # Person 1: A=0.1, B=0.1, C=0.1
    # Person 2: A=0.1, B=0.1, C=0.1
    # Person 3: A=0.1, B=0.1, C=0.1
    # Person 4: A=0.1, B=0.1, C=0.1
    # Sum per person: 0.3
    # Total sum for 5: 1.5 (Too much)
    # Check subset of 4: 1.2 (Too much)
    # Check subset of 3: 0.9 (Valid)
    # Result: 3
    
    print("
Test Case 3: Many small requirements")
    
    dut.req_A.value = 0
    dut.req_B.value = 0
    dut.req_C.value = 0
    dut.num_people.value = 5
    
    req_val = to_q1616(0.1) # 6553
    
    for i in range(5):
        dut.req_A[i].value = req_val
        dut.req_B[i].value = req_val
        dut.req_C[i].value = req_val
    
    await Timer(10, units='ns')
    
    result = int(dut.max_satisfied.value)
    print(f"Expected: 3, Got: {result}")
    assert result == 3, f"Test 3 failed: expected 3, got {result}"

    # Test Case 4: Edge case, 1 person
    # Person 0: A=0.5, B=0.3, C=0.2 (Sum=1.0)
    print("
Test Case 4: Single person exactly 1.0")
    
    dut.req_A.value = 0
    dut.req_B.value = 0
    dut.req_C.value = 0
    dut.num_people.value = 1
    
    dut.req_A[0].value = to_q1616(0.5)
    dut.req_B[0].value = to_q1616(0.3)
    dut.req_C[0].value = to_q1616(0.2)
    
    await Timer(10, units='ns')
    
    result = int(dut.max_satisfied.value)
    print(f"Expected: 1, Got: {result}")
    assert result == 1, f"Test 4 failed: expected 1, got {result}"

    print("
All tests passed!")
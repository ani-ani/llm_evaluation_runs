import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_common_elements(dut):
    """Test the common_elements module"""
    
    # Test Case 1: From original
    # l1 = [1, 1, 3, 4, 5, 6, 7] -> padded to [1,1,3,4,5,6,7,0]
    # l2 = [0, 1, 2, 3, 4, 5, 7] -> padded to [0,1,2,3,4,5,7,0]
    # l3 = [0, 1, 2, 3, 4, 5, 7] -> padded to [0,1,2,3,4,5,7,0]
    # Matches: Index 1 (1==1==1), Index 6 (7==7==7)
    l1_1 = [1, 1, 3, 4, 5, 6, 7, 0]
    l2_1 = [0, 1, 2, 3, 4, 5, 7, 0]
    l3_1 = [0, 1, 2, 3, 4, 5, 7, 0]
    expected_1 = [0, 1, 0, 0, 0, 0, 7, 0]

    # Test Case 2: From original
    # l1 = [1, 1, 3, 4, 5, 6, 7] -> [1,1,3,4,5,6,7,0]
    # l2 = [0, 1, 2, 3, 4, 6, 5] -> [0,1,2,3,4,6,5,0]
    # l3 = [0, 1, 2, 3, 4, 6, 7] -> [0,1,2,3,4,6,7,0]
    # Matches: Index 1 (1==1==1), Index 5 (6==6==6)
    l1_2 = [1, 1, 3, 4, 5, 6, 7, 0]
    l2_2 = [0, 1, 2, 3, 4, 6, 5, 0]
    l3_2 = [0, 1, 2, 3, 4, 6, 7, 0]
    expected_2 = [0, 1, 0, 0, 0, 6, 0, 0]

    # Test Case 3: From original
    # l1 = [1, 1, 3, 4, 6, 5, 6] -> [1,1,3,4,6,5,6,0]
    # l2 = [0, 1, 2, 3, 4, 5, 7] -> [0,1,2,3,4,5,7,0]
    # l3 = [0, 1, 2, 3, 4, 5, 7] -> [0,1,2,3,4,5,7,0]
    # Matches: Index 1 (1==1==1)
    l1_3 = [1, 1, 3, 4, 6, 5, 6, 0]
    l2_3 = [0, 1, 2, 3, 4, 5, 7, 0]
    l3_3 = [0, 1, 2, 3, 4, 5, 7, 0]
    expected_3 = [0, 1, 0, 0, 0, 0, 0, 0]

    # Test Case 4: From original (Empty result)
    # l1 = [1, 2, 3, 4, 6, 6, 6] -> [1,2,3,4,6,6,6,0]
    # l2 = [0, 1, 2, 3, 4, 5, 7] -> [0,1,2,3,4,5,7,0]
    # l3 = [0, 1, 2, 3, 4, 5, 7] -> [0,1,2,3,4,5,7,0]
    l1_4 = [1, 2, 3, 4, 6, 6, 6, 0]
    l2_4 = [0, 1, 2, 3, 4, 5, 7, 0]
    l3_4 = [0, 1, 2, 3, 4, 5, 7, 0]
    expected_4 = [0, 0, 0, 0, 0, 0, 0, 0]

    test_cases = [
        (l1_1, l2_1, l3_1, expected_1),
        (l1_2, l2_2, l3_2, expected_2),
        (l1_3, l2_3, l3_3, expected_3),
        (l1_4, l2_4, l3_4, expected_4)
    ]

    passed = 0
    total = len(test_cases)

    for i, (l1_in, l2_in, l3_in, expected) in enumerate(test_cases):
        # Assign inputs
        for j in range(8):
            dut.l1[j].value = l1_in[j]
            dut.l2[j].value = l2_in[j]
            dut.l3[j].value = l3_in[j]
        
        # Wait for combinational logic to settle
        await Timer(10, units='ns')
        
        # Check outputs
        fail = False
        for j in range(8):
            actual = int(dut.result[j].value)
            if actual != expected[j]:
                dut._log.error(f"Test {i+1}, Index {j}: Expected {expected[j]}, Got {actual}")
                fail = True
        
        if not fail:
            passed += 1
            dut._log.info(f"Test {i+1} passed")
        else:
            dut._log.error(f"Test {i+1} failed")

    dut._log.info(f"Summary: {passed}/{total} tests passed")
    assert passed == total, f"Only {passed}/{total} tests passed"
import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_tuple_max(dut):
    # Test cases: (tup1_matrix, tup2_matrix, expected_result)
    test_cases = [
        (
            # Input tuple1 (row0, row1, row2, row3)
            ((1,3),(4,5),(2,9),(1,10)),
            # Input tuple2 (row0, row1, row2, row3)
            ((6,7),(3,9),(1,1),(7,3)),
            # Expected result
            ((6,7),(4,9),(2,9),(7,10))
        ),
        (
            ((2,4),(5,6),(3,10),(2,11)),
            ((7,8),(4,10),(2,2),(8,4)),
            ((7,8),(5,10),(3,10),(8,11))
        ),
        (
            ((3,5),(6,7),(4,11),(3,12)),
            ((8,9),(5,11),(3,3),(9,5)),
            ((8,9),(6,11),(4,11),(9,12))
        ),
        # Additional edge cases
        (
            ((0,15),(15,0),(15,15),(0,0)),
            ((15,0),(0,15),(0,0),(15,15)),
            ((15,15),(15,15),(15,15),(15,15))
        )
    ]
    
    passed = 0
    for idx, (tup1, tup2, expected) in enumerate(test_cases):
        # Set input signals
        dut.t1_0_0.value = tup1[0][0]
        dut.t1_0_1.value = tup1[0][1]
        dut.t1_1_0.value = tup1[1][0]
        dut.t1_1_1.value = tup1[1][1]
        dut.t1_2_0.value = tup1[2][0]
        dut.t1_2_1.value = tup1[2][1]
        dut.t1_3_0.value = tup1[3][0]
        dut.t1_3_1.value = tup1[3][1]
        
        dut.t2_0_0.value = tup2[0][0]
        dut.t2_0_1.value = tup2[0][1]
        dut.t2_1_0.value = tup2[1][0]
        dut.t2_1_1.value = tup2[1][1]
        dut.t2_2_0.value = tup2[2][0]
        dut.t2_2_1.value = tup2[2][1]
        dut.t2_3_0.value = tup2[3][0]
        dut.t2_3_1.value = tup2[3][1]
        
        await Timer(1, units='ns')
        
        # Verify all output elements
        correct = True
        errors = []
        for r in range(4):
            for c in range(2):
                actual = getattr(dut, f"res_{r}_{c}").value.integer
                exp = expected[r][c]
                if actual != exp:
                    correct = False
                    errors.append(f"Row {r} Col {c}: Expected {exp}, got {actual}")
        
        if correct:
            passed += 1
            dut._log.info(f"Test {idx} PASSED")
        else:
            dut._log.error(f"Test {idx} FAILED
Errors:
{"
".join(errors)}")
    
    dut._log.info(f"
SUMMARY: {passed}/{len(test_cases)} tests passed")
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

@cocotb.test()
async def test_sorter(dut):
    # Setup: Clock and reset
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Test cases: (input_scores, expected_sorted_scores, expected_indices)
    test_cases = [
        ([88, 90, 97, 82], [82, 88, 90, 97], [3, 0, 1, 2]),  # Test Case 1
        ([49, 54, 33, 0], [0, 33, 49, 54], [3, 2, 0, 1]),    # Test Case 2
        ([96, 97, 45, 0], [0, 45, 96, 97], [3, 2, 0, 1])     # Test Case 3
    ]
    subject_names = [
        ['English', 'Science', 'Maths', 'Social sciences'],
        ['Telugu', 'Hindhi', 'Social', ''],
        ['Physics', 'Chemistry', 'Biology', '']
    ]
    
    passed = 0
    
    for i, (scores, exp_scores, exp_indices) in enumerate(test_cases):
        # Apply reset
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Load input
        for idx in range(4):
            dut.scores[idx].value = scores[idx]
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Verify results
        sorted_names = [subject_names[i][int(dut.sorted_indices[idx].value)] for idx in range(4)]
        actual_scores = [int(dut.sorted_scores[idx].value) for idx in range(4)]
        
        if (actual_scores == exp_scores and 
            [int(dut.sorted_indices[idx].value) for idx in range(4)] == exp_indices):
            passed += 1
            dut._log.info(f"PASS TC{i+1}: {sorted_names} with scores {actual_scores}")
        else:
            dut._log.error(f"FAIL TC{i+1}: Got {sorted_names} (scores {actual_scores})\
                          Expected {[subject_names[i][idx] for idx in exp_indices]} (scores {exp_scores})")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
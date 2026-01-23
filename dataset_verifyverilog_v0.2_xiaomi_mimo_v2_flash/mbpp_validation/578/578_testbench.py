import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_interleave_lists(dut):
    """Test interleaving of 3 lists"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.list1_data.value = 0
    dut.list2_data.value = 0
    dut.list3_data.value = 0
    dut.list1_valid.value = 0
    dut.list2_valid.value = 0
    dut.list3_valid.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: 3 elements each
    # Expected: [1,10,100,2,20,200,3,30,300]
    list1 = [1, 2, 3]
    list2 = [10, 20, 30]
    list3 = [100, 200, 300]
    
    # Reset for new test
    dut.start.value = 0
    await RisingEdge(dut.clk)
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Process interleaving
    expected = []
    for i in range(3):
        expected.extend([list1[i], list2[i], list3[i]])
    
    output_idx = 0
    current_list = 0
    list_indices = [0, 0, 0]
    
    # Run simulation for enough cycles
    for cycle in range(100):
        await RisingEdge(dut.clk)
        await Timer(1, units='ns')  # Small delay for signals to settle
        
        # Check if reading
        if dut.rd_en.value != 0:
            if dut.rd_en.value & 1:  # Reading list1
                if list_indices[0] < len(list1):
                    dut.list1_data.value = list1[list_indices[0]]
                    dut.list1_valid.value = 1
                else:
                    dut.list1_valid.value = 0
            else:
                dut.list1_valid.value = 0
                
            if dut.rd_en.value & 2:  # Reading list2
                if list_indices[1] < len(list2):
                    dut.list2_data.value = list2[list_indices[1]]
                    dut.list2_valid.value = 1
                else:
                    dut.list2_valid.value = 0
            else:
                dut.list2_valid.value = 0
                
            if dut.rd_en.value & 4:  # Reading list3
                if list_indices[2] < len(list3):
                    dut.list3_data.value = list3[list_indices[2]]
                    dut.list3_valid.value = 1
                else:
                    dut.list3_valid.value = 0
            else:
                dut.list3_valid.value = 0
        else:
            dut.list1_valid.value = 0
            dut.list2_valid.value = 0
            dut.list3_valid.value = 0
        
        # Check output
        if dut.result_valid.value and output_idx < len(expected):
            actual = int(dut.result.value)
            exp = expected[output_idx]
            if actual != exp:
                raise TestFailure(f"Cycle {cycle}: Output mismatch at index {output_idx}. Expected {exp}, got {actual}")
            output_idx += 1
            
        # Update indices based on rd_en
        if dut.result_valid.value and dut.rd_en.value != 0:
            if dut.rd_en.value & 1 and list_indices[0] < len(list1):
                list_indices[0] += 1
            if dut.rd_en.value & 2 and list_indices[1] < len(list2):
                list_indices[1] += 1
            if dut.rd_en.value & 4 and list_indices[2] < len(list3):
                list_indices[2] += 1
        
        # Check done
        if dut.done.value:
            break
    
    # Verify all output consumed
    if output_idx != len(expected):
        raise TestFailure(f"Expected {len(expected)} outputs, got {output_idx}")
    
    print(f"Test 1 passed: All {output_idx} elements correct")
    
    # Test case 2: 2 elements each
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    list1 = [10, 20]
    list2 = [15, 2]
    list3 = [5, 10]
    expected = [10, 15, 5, 20, 2, 10]
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    output_idx = 0
    list_indices = [0, 0, 0]
    
    for cycle in range(100):
        await RisingEdge(dut.clk)
        await Timer(1, units='ns')
        
        if dut.rd_en.value != 0:
            if dut.rd_en.value & 1:
                if list_indices[0] < len(list1):
                    dut.list1_data.value = list1[list_indices[0]]
                    dut.list1_valid.value = 1
                else:
                    dut.list1_valid.value = 0
            else:
                dut.list1_valid.value = 0
                
            if dut.rd_en.value & 2:
                if list_indices[1] < len(list2):
                    dut.list2_data.value = list2[list_indices[1]]
                    dut.list2_valid.value = 1
                else:
                    dut.list2_valid.value = 0
            else:
                dut.list2_valid.value = 0
                
            if dut.rd_en.value & 4:
                if list_indices[2] < len(list3):
                    dut.list3_data.value = list3[list_indices[2]]
                    dut.list3_valid.value = 1
                else:
                    dut.list3_valid.value = 0
            else:
                dut.list3_valid.value = 0
        else:
            dut.list1_valid.value = 0
            dut.list2_valid.value = 0
            dut.list3_valid.value = 0
        
        if dut.result_valid.value and output_idx < len(expected):
            actual = int(dut.result.value)
            exp = expected[output_idx]
            if actual != exp:
                raise TestFailure(f"Test 2 Cycle {cycle}: Output mismatch at index {output_idx}. Expected {exp}, got {actual}")
            output_idx += 1
            
        if dut.result_valid.value and dut.rd_en.value != 0:
            if dut.rd_en.value & 1 and list_indices[0] < len(list1):
                list_indices[0] += 1
            if dut.rd_en.value & 2 and list_indices[1] < len(list2):
                list_indices[1] += 1
            if dut.rd_en.value & 4 and list_indices[2] < len(list3):
                list_indices[2] += 1
        
        if dut.done.value:
            break
    
    if output_idx != len(expected):
        raise TestFailure(f"Test 2: Expected {len(expected)} outputs, got {output_idx}")
    
    print(f"Test 2 passed: All {output_idx} elements correct")
    
    # Test case 3: 2 elements each (different values)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    list1 = [11, 44]
    list2 = [10, 15]
    list3 = [20, 5]
    expected = [11, 10, 20, 44, 15, 5]
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    output_idx = 0
    list_indices = [0, 0, 0]
    
    for cycle in range(100):
        await RisingEdge(dut.clk)
        await Timer(1, units='ns')
        
        if dut.rd_en.value != 0:
            if dut.rd_en.value & 1:
                if list_indices[0] < len(list1):
                    dut.list1_data.value = list1[list_indices[0]]
                    dut.list1_valid.value = 1
                else:
                    dut.list1_valid.value = 0
            else:
                dut.list1_valid.value = 0
                
            if dut.rd_en.value & 2:
                if list_indices[1] < len(list2):
                    dut.list2_data.value = list2[list_indices[1]]
                    dut.list2_valid.value = 1
                else:
                    dut.list2_valid.value = 0
            else:
                dut.list2_valid.value = 0
                
            if dut.rd_en.value & 4:
                if list_indices[2] < len(list3):
                    dut.list3_data.value = list3[list_indices[2]]
                    dut.list3_valid.value = 1
                else:
                    dut.list3_valid.value = 0
            else:
                dut.list3_valid.value = 0
        else:
            dut.list1_valid.value = 0
            dut.list2_valid.value = 0
            dut.list3_valid.value = 0
        
        if dut.result_valid.value and output_idx < len(expected):
            actual = int(dut.result.value)
            exp = expected[output_idx]
            if actual != exp:
                raise TestFailure(f"Test 3 Cycle {cycle}: Output mismatch at index {output_idx}. Expected {exp}, got {actual}")
            output_idx += 1
            
        if dut.result_valid.value and dut.rd_en.value != 0:
            if dut.rd_en.value & 1 and list_indices[0] < len(list1):
                list_indices[0] += 1
            if dut.rd_en.value & 2 and list_indices[1] < len(list2):
                list_indices[1] += 1
            if dut.rd_en.value & 4 and list_indices[2] < len(list3):
                list_indices[2] += 1
        
        if dut.done.value:
            break
    
    if output_idx != len(expected):
        raise TestFailure(f"Test 3: Expected {len(expected)} outputs, got {output_idx}")
    
    print(f"Test 3 passed: All {output_idx} elements correct")
    print("All tests passed!")
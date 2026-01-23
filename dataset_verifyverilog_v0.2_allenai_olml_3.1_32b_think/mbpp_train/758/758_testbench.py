import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

@cocotb.test()
async def test_sublist_histogram(dut):
    """Test sublist histogram functionality"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.num_sublists.value = 0
    for i in range(8):
        dut.sublist_lengths[i].value = 0
        for j in range(8):
            dut.sublists[i][j].value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: [[1, 3], [5, 7], [1, 3], [13, 15, 17], [5, 7], [9, 11]]
    dut.num_sublists.value = 6
    
    # Sublist 0: [1, 3]
    dut.sublist_lengths[0].value = 2
    dut.sublists[0][0].value = 1
    dut.sublists[0][1].value = 3
    
    # Sublist 1: [5, 7]
    dut.sublist_lengths[1].value = 2
    dut.sublists[1][0].value = 5
    dut.sublists[1][1].value = 7
    
    # Sublist 2: [1, 3]
    dut.sublist_lengths[2].value = 2
    dut.sublists[2][0].value = 1
    dut.sublists[2][1].value = 3
    
    # Sublist 3: [13, 15, 17]
    dut.sublist_lengths[3].value = 3
    dut.sublists[3][0].value = 13
    dut.sublists[3][1].value = 15
    dut.sublists[3][2].value = 17
    
    # Sublist 4: [5, 7]
    dut.sublist_lengths[4].value = 2
    dut.sublists[4][0].value = 5
    dut.sublists[4][1].value = 7
    
    # Sublist 5: [9, 11]
    dut.sublist_lengths[5].value = 2
    dut.sublists[5][0].value = 9
    dut.sublists[5][1].value = 11
    
    # Start computation
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Collect results
    results = {}
    output_count = 0
    max_cycles = 50
    
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if dut.output_valid.value == 1:
            # Read output sublist
            length = int(dut.list_length.value)
            sublist = []
            for i in range(length):
                sublist.append(int(dut.unique_list[i].value))
            count = int(dut.count.value)
            results[tuple(sublist)] = count
            output_count += 1
        if dut.done.value == 1:
            break
    
    # Verify results
    expected = {(1, 3): 2, (5, 7): 2, (13, 15, 17): 1, (9, 11): 1}
    
    if len(results) != len(expected):
        raise TestFailure(f"Expected {len(expected)} unique sublists, got {len(results)}")
    
    for sublist, count in results.items():
        if sublist not in expected:
            raise TestFailure(f"Unexpected sublist {sublist} in results")
        if expected[sublist] != count:
            raise TestFailure(f"Count mismatch for {sublist}: expected {expected[sublist]}, got {count}")
    
    print(f"Test Case 1 passed: {output_count} outputs collected")
    
    # Reset for next test
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 2: [[10, 20, 30, 40], [60, 70, 50, 50], [90, 100, 200]]
    dut.num_sublists.value = 3
    
    # Sublist 0: [10, 20, 30, 40]
    dut.sublist_lengths[0].value = 4
    dut.sublists[0][0].value = 10
    dut.sublists[0][1].value = 20
    dut.sublists[0][2].value = 30
    dut.sublists[0][3].value = 40
    
    # Sublist 1: [60, 70, 50, 50]
    dut.sublist_lengths[1].value = 4
    dut.sublists[1][0].value = 60
    dut.sublists[1][1].value = 70
    dut.sublists[1][2].value = 50
    dut.sublists[1][3].value = 50
    
    # Sublist 2: [90, 100, 200]
    dut.sublist_lengths[2].value = 3
    dut.sublists[2][0].value = 90
    dut.sublists[2][1].value = 100
    dut.sublists[2][2].value = 200
    
    # Start computation
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Collect results
    results = {}
    output_count = 0
    
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if dut.output_valid.value == 1:
            length = int(dut.list_length.value)
            sublist = []
            for i in range(length):
                sublist.append(int(dut.unique_list[i].value))
            count = int(dut.count.value)
            results[tuple(sublist)] = count
            output_count += 1
        if dut.done.value == 1:
            break
    
    # Verify results
    expected = {(10, 20, 30, 40): 1, (60, 70, 50, 50): 1, (90, 100, 200): 1}
    
    if len(results) != len(expected):
        raise TestFailure(f"Expected {len(expected)} unique sublists, got {len(results)}")
    
    for sublist, count in results.items():
        if sublist not in expected:
            raise TestFailure(f"Unexpected sublist {sublist} in results")
        if expected[sublist] != count:
            raise TestFailure(f"Count mismatch for {sublist}: expected {expected[sublist]}, got {count}")
    
    print(f"Test Case 2 passed: {output_count} outputs collected")
    print(f"All {output_count} tests passed")
}
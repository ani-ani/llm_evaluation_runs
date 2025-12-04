import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_cycle_partition(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Test cases (adj matrix for 4-node graphs)
    # 0↔1, 2↔3: valid partition (adj_matrix= 0->1,1->0,2->3,3->2)
    test1 = 0b0000_0000_0010_0101 # matrix[0][1]=1, [1][0]=1, [2][3]=1, [3][2]=1
    # 0↔1, 2→3→3: invalid (adj_matrix= 0->1,1->0,2->3,3->3)
    test2 = 0b0000_0000_0001_0101 # [2][3]=1, [3][3]=1, [0][1]=1, [1][0]=1
    # Single node cycle (0→0)
    test3 = 0b0001_0000_0000_0000 # [0][0]=1
    
    test_cases = [
        (test1, 0, 0b0011, 2),  # valid, first cycle 0&1
        (test2, 1, 0, 0),       # invalid
        (test3, 0, 0b0001, 1)   # valid single-node
    ]
    
    dut._log.info("Initialize and reset")
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    
    passed = 0
    for idx, (adj, expected_valid, expected_nodes, expected_size) in enumerate(test_cases):
        dut.start.value = 0
        dut.adj_matrix_flat.value = adj
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait 10 cycles for computation
        for _ in range(11):
            await RisingEdge(dut.clk)
        
        if dut.done.value != 1:
            dut._log.error(f"Test {idx} failed: done not asserted")
        elif dut.valid_partition.value != expected_valid:
            dut._log.error(f"Test {idx} failed: valid_partition={dut.valid_partition.value} vs {expected_valid}")
        elif not expected_valid and (dut.node_list.value != expected_nodes or dut.cycle_size.value != expected_size):
            dut._log.error(f"Test {idx} failed: nodes={bin(dut.node_list.value)} size={dut.cycle_size.value} vs expected {bin(expected_nodes)}/{expected_size}")
        else:
            passed += 1
            dut._log.info(f"Test {idx} passed")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")"
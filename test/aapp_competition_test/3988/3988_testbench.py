import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_graph_reachability(dut):
    # Create 50MHz clock
    cocotb.start_soon(Clock(dut.clk, 20, units="ns").start())

    async def reset():
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

    await reset()
    test_cases = [
        # Test 1: 2 nodes, 2 edges (1 directed, 1 undirected)
        {"start": 0, "edges": [[1,0,1], [2,1,0]], 
         "exp_max": 2, "exp_min": 2, 
         "exp_max_o": 0b0, "exp_min_o": 0b1},
        # Test 2: 3 nodes with mixed edges
        {"start": 1, "edges": [[2,0,1], [1,2,0], [2,2,1]], 
         "exp_max": 3, "exp_min": 1, 
         "exp_max_o": 0b110, "exp_min_o": 0b000},
        # Test 3: Linear chain topology
        {"start": 0, "edges": [[2,0,1], [2,1,2], [2,2,3]], 
         "exp_max": 4, "exp_min": 1, 
         "exp_max_o": 0b111, "exp_min_o": 0b000}
    ]
    passed = 0
    for idx, tc in enumerate(test_cases):
        # Wait 2 cycles between tests
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)

        # Load test case inputs
        dut.edge_count.value = len(tc['edges'])
        dut.start_node.value = tc['start']
        for i in range(16):
            if i < len(tc['edges']):
                dut.graph_nodes[i][0].value = tc['edges'][i][0]
                dut.graph_nodes[i][1].value = tc['edges'][i][1]
                dut.graph_nodes[i][2].value = tc['edges'][i][2]
            else:
                dut.graph_nodes[i][0].value = 0
                dut.graph_nodes[i][1].value = 0
                dut.graph_nodes[i][2].value = 0
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done signal (max 32 cycles)
        timeout = 0
        while dut.done.value != 1 and timeout < 40:
            await RisingEdge(dut.clk)
            timeout += 1
        
        if timeout >= 40:
            dut._log.error(f"Test {idx} timed out")
            continue
        
        # Verify outputs
        max_ok = (dut.max_reachable.value == tc['exp_max'])
        min_ok = (dut.min_reachable.value == tc['exp_min'])
        max_orient_ok = (dut.max_orient.value == tc['exp_max_o'])
        min_orient_ok = (dut.min_orient.value == tc['exp_min_o'])
        
        if max_ok and min_ok and max_orient_ok and min_orient_ok:
            passed += 1
        else:
            errors = []
            if not max_ok: errors.append(f"Max reachable: {dut.max_reachable.value} != {tc['exp_max']}")
            if not min_ok: errors.append(f"Min reachable: {dut.min_reachable.value} != {tc['exp_min']}")
            if not max_orient_ok: errors.append(f"Max orient: {bin(dut.max_orient.value)} != {bin(tc['exp_max_o'])}")
            if not min_orient_ok: errors.append(f"Min orient: {bin(dut.min_orient.value)} != {bin(tc['exp_min_o'])}")
            dut._log.error(f"Test {idx} failed: {', '.join(errors)}")

    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)
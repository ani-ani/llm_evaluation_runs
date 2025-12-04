import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_army_move(dut):
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # First test case (Sample Input 3 nations)
    test1 = {
        "num_nations": 3,
        "parent_node": [1, 0, 1],  # node0 parent=1, node1=root, node2 parent=1
        "move_costs": [0, 5, 5],    # cost to parent
        "init_armies": [2, 5, 1],   # nations 1-3 x_i values
        "req_armies": [1, 0, 3]     # y_i values
    }
    
    # Second test case (Scaled Sample Input 6 nations)
    test2 = {
        "num_nations": 6,
        "parent_node": [1,0,1,1,2,2],
        "move_costs": [0,2,5,1,5,1],
        "init_armies": [0,1,2,2,0,0],
        "req_armies": [0,0,1,1,1,1]
    }
    
    test_cases = [
        (test1, 15),
        (test2, 9)
    ]
    
    passed = 0
    
    for test_data, expected_cost in test_cases:
        # Apply reset
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Load test data
        dut.num_nations.value = test_data["num_nations"]
        for i in range(8):
            dut.parent_node[i].value = test_data["parent_node"][i] if i < test_data["num_nations"] else 0
            dut.move_costs[i].value = test_data["move_costs"][i] if i < test_data["num_nations"] else 0
            dut.init_armies[i].value = test_data["init_armies"][i] if i < test_data["num_nations"] else 0
            dut.req_armies[i].value = test_data["req_armies"][i] if i < test_data["num_nations"] else 0
        
        # Start calculation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done (+16 cycles)
        for _ in range(18):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        
        # Check result
        if dut.done.value == 1:
            result = dut.total_cost.value.integer
            if result == expected_cost:
                passed += 1
            else:
                dut._log.error(f"Test failed: Expected {expected_cost}, got {result}")
        else:
            dut._log.error("Test timed out waiting for done")
        
    # Test summary
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)
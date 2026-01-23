import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_crush_game(dut):
    """Test the Crush Game module with various graph configurations"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    for i in range(16):
        dut.crush[i].value = 0
    
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Helper function to run a test
    async def run_test(n_val, crush_list, expected, test_name):
        dut._log.info(f"Running test: {test_name}")
        
        # Set inputs
        dut.n.value = n_val
        for i in range(16):
            if i < len(crush_list):
                dut.crush[i].value = crush_list[i]
            else:
                dut.crush[i].value = 0
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 300
        for _ in range(timeout):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        
        # Check result
        result = int(dut.result.value)
        dut._log.info(f"Result: {result}, Expected: {expected}")
        assert result == expected, f"Expected {expected}, got {result}"
    
    # Test 1: Simple cycle of length 3 (odd) -> LCM = 3
    # 1->2->3->1 (0->1->2->0)
    await run_test(3, [1, 2, 0], 3, "3-cycle (odd)")
    
    # Test 2: Self loops (cycle length 1) -> LCM = 1
    # 1->1, 2->2, 3->3, 4->4
    await run_test(4, [0, 1, 2, 3], 1, "4 self-loops")
    
    # Test 3: Two cycles: 3-cycle (odd=3) and 4-cycle (even=2) -> LCM(3,2) = 6
    # But need to reconfigure: Let's use the 2-cycle from example
    # Graph: 1->2->1 (cycle len 2, adjusted to 1), 3->4->5->3 (cycle len 3, adjusted to 3)
    # Wait, let's use simpler: 2-cycle and 3-cycle
    # 0->1->0 (len 2, adj 1), 2->3->4->2 (len 3, adj 3) -> LCM(1,3)=3
    # Actually let's test the case: 2-cycle and 2-cycle = LCM(1,1)=1
    await run_test(4, [1, 0, 3, 2], 1, "Two 2-cycles")
    
    # Test 4: Example from problem - 4 nodes
    # 1->2, 2->3, 3->1 (cycle len 3), 4->4 (cycle len 1)
    # Input: 2 3 1 4 (1-indexed) -> [1, 2, 0, 3] (0-indexed)
    # LCM(3, 1) = 3
    await run_test(4, [1, 2, 0, 3], 3, "Problem example 1")
    
    # Test 5: Invalid - node points to 4-cycle, but 1,2,3,4 not all in cycle
    # Graph: 0->1, 1->2, 2->3, 3->1 (cycle 1,2,3), but 0 points to 1
    # 0->1->2->3->1->... 0 never returns to 0
    # This should return -1
    await run_test(4, [1, 2, 3, 1], -1, "Invalid: 0 not in cycle")
    
    # Test 6: Single node, self-loop
    await run_test(1, [0], 1, "Single self-loop")
    
    # Test 7: 2-cycle (even) -> adjusted to 1
    # 1->2->1 -> LCM = 1
    await run_test(2, [1, 0], 1, "2-cycle")
    
    # Test 8: 5-cycle (odd) -> LCM = 5
    await run_test(5, [1, 2, 3, 4, 0], 5, "5-cycle")
    
    # Test 9: 6-cycle (even) -> adjusted to 3
    await run_test(6, [1, 2, 3, 4, 5, 0], 3, "6-cycle")
    
    # Test 10: Mixed - 3-cycle and 6-cycle
    # 0->1->2->0 (len 3), 3->4->5->6->7->8->3 (len 6 -> 3)
    # LCM(3,3) = 3
    # Need 9 nodes: 0,1,2 cycle; 3,4,5,6,7,8 cycle
    await run_test(9, [1, 2, 0, 4, 5, 6, 7, 8, 3], 3, "3-cycle and 6-cycle")
    
    print(f"
All tests passed!")

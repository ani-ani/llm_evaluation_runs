import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
from cocotb.utils import get_sim_time

@cocotb.test()
async def test_purchase(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    passed = 0
    
    async def reset()
        dut.rst_n.value = 0
        dut.start.value = 0
        await Timer(20, units="ns") # Hold reset for 2 cycles
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
    
    async def run_test_case(counts, purchases, exp_counts):
        # Initialize state
        await reset()
        dut.child_count.value = [counts[i] if i < len(counts) else 0 for i in range(4)]
        dut.purchase_count.value = len(purchases)
        for i in range(len(purchases)):
            dut.purchase_pairs[i][0].value = purchases[i][0]
            dut.purchase_pairs[i][1].value = purchases[i][1]
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)
        results = [dut.outcome[i].value for i in range(len(purchases))]
        
        # Simulate card distribution
        current = [0]*4
        for i in range(len(purchases)):
            a = purchases[i][0]
            b = purchases[i][1]
            out = results[i]
            if out == 0:
                current[b] += 2
            elif out == 1:
                current[a] += 1
                current[b] += 1
            else: # out == 2
                current[a] += 2
            
        # Verification
        success = True
        for i in range(4):
            if current[i] != (counts[i] if i < len(counts) else 0):
                dut._log.error(f"Error: Child {i} got {current[i]} expected {counts[i] if i < len(counts) else 0}")
                success = False
        if success:
            passed += 1
            dut._log.info("Test passed")
    
    # Test 1: Sample Input 1
    await run_test_case(
        counts=[5,1], 
        purchases=[[0,1],[0,1],[0,1]],
        exp_counts=[5,1,0,0])
    
    # Test 2: Custom Test Case
    await run_test_case(
        counts=[4,2], 
        purchases=[[0,1],[0,1],[0,1]],
        exp_counts=[4,2,0,0])
    
    # Report
    total_tests = 2
    dut._log.info(f"{passed}/{total_tests} tests passed")
    assert passed == total_tests
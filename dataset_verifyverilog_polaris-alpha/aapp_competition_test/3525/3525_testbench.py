import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles

@cocotb.test()
async def test_badge_counter(dut):
    clock = Clock(dut.clk, 10, units="ns")  
    cocotb.start_soon(clock.start())
    
    # Test case 1: Original sample input (expected 5)
    lock_src1 = [0, 2, 2, 1, 3]  # rooms: 1=0, 2=1, 3=2,4=3 
    lock_dst1 = [1, 0, 3, 3, 1]  # converted to 0-based index 
    lock_min1 = [4, 1, 7, 3, 8]  
    lock_max1 = [7, 6, 10, 5, 9]  
    
    # Test case 2: Second sample input (expected 5)
    lock_src2 = [0, 0, 0, 1, 2]  
    lock_dst2 = [1, 2, 3, 3, 3]  
    lock_min2 = [3, 6, 2, 4, 7]  
    lock_max2 = [5, 7, 3, 6, 9]  
    
    test_vector = [
        # S, D, lock_src, lock_dst, lock_min, lock_max, expected 
        (3-1, 2-1, lock_src1, lock_dst1, lock_min1, lock_max1, 5), 
        (1-1, 4-1, lock_src2, lock_dst2, lock_min2, lock_max2, 5) 
    ] 
\
    passed = 0
    for i, (S, D, srcs, dsts, mins, maxs, expected) in enumerate(test_vector):
        # Setup lock data 
        for j in range(5):
            dut.lock_src[j].value = srcs[j]
            dut.lock_dst[j].value = dsts[j]
            dut.lock_min[j].value = mins[j]
            dut.lock_max[j].value = maxs[j]
        
        # Reset and start 
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Trigger computation 
        dut.S.value = S
        dut.D.value = D
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done (max 60 cycles)
        for _ in range(60):
            if dut.done.value:
                break
            await RisingEdge(dut.clk)
        
        assert dut.done.value, "Test timed out"
        
        if dut.result.value == expected:
            passed += 1
        else:
            dut._log.error(f"Test {i} failed: Got {dut.result.value}, expected {expected}")
        
        # Reset between tests 
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
    
    dut._log.info(f"{passed}/{len(test_vector)} tests passed")

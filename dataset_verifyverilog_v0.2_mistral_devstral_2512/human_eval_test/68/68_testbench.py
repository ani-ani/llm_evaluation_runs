import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_pluck_module(dut):
    """Test the pluck module with various test cases"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.arr_in.value = 0
    dut.arr_index.value = 0
    dut.valid_in.value = 0
    dut.last_in.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    async def run_test(arr, expected):
        """Helper to run one test case"""
        # Start pulse
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for ready
        while not dut.ready.value:
            await RisingEdge(dut.clk)
        
        # Send array elements
        for i, val in enumerate(arr):
            dut.arr_in.value = val
            dut.arr_index.value = i
            dut.valid_in.value = 1
            dut.last_in.value = (i == len(arr) - 1)
            await RisingEdge(dut.clk)
            dut.valid_in.value = 0
            dut.last_in.value = 0
        
        # Wait for done
        timeout = 100
        for _ in range(timeout):
            if dut.done.value:
                break
            await RisingEdge(dut.clk)
        else:
            raise TestFailure("Timeout waiting for done")
        
        # Check result
        actual = int(dut.result.value)
        if actual != expected:
            raise TestFailure(f"Expected {expected:#x}, got {actual:#x}")
        
        # Wait for idle
        await RisingEdge(dut.clk)
    
    # Test 1: [4, 2, 3] -> [2, 1]
    # 2 = 0x0002, index 1 = 0x0001 -> result 0x00010002
    dut._log.info("Test 1: [4, 2, 3]")
    await run_test([4, 2, 3], 0x00010002)
    
    # Test 2: [1, 2, 3] -> [2, 1]
    dut._log.info("Test 2: [1, 2, 3]")
    await run_test([1, 2, 3], 0x00010002)
    
    # Test 3: [] -> []
    dut._log.info("Test 3: []")
    await run_test([], 0x00000000)
    
    # Test 4: [5, 0, 3, 0, 4, 2] -> [0, 1]
    # 0 = 0x0000, index 1 = 0x0001 -> result 0x00010000
    dut._log.info("Test 4: [5, 0, 3, 0, 4, 2]")
    await run_test([5, 0, 3, 0, 4, 2], 0x00010000)
    
    # Test 5: [1, 2, 3, 0, 5, 3] -> [0, 3]
    # 0 = 0x0000, index 3 = 0x0003 -> result 0x00030000
    dut._log.info("Test 5: [1, 2, 3, 0, 5, 3]")
    await run_test([1, 2, 3, 0, 5, 3], 0x00030000)
    
    # Test 6: [5, 4, 8, 4, 8] -> [4, 1]
    # 4 = 0x0004, index 1 = 0x0001 -> result 0x00010004
    dut._log.info("Test 6: [5, 4, 8, 4, 8]")
    await run_test([5, 4, 8, 4, 8], 0x00010004)
    
    # Test 7: [7, 6, 7, 1] -> [6, 1]
    # 6 = 0x0006, index 1 = 0x0001 -> result 0x00010006
    dut._log.info("Test 7: [7, 6, 7, 1]")
    await run_test([7, 6, 7, 1], 0x00010006)
    
    # Test 8: [7, 9, 7, 1] -> no even
    dut._log.info("Test 8: [7, 9, 7, 1]")
    await run_test([7, 9, 7, 1], 0x00000000)
    
    # Test 9: Edge case - all zeros
    dut._log.info("Test 9: [0, 0, 0]")
    await run_test([0, 0, 0], 0x00000000)
    
    # Test 10: Max size array
    dut._log.info("Test 10: [1,1,1,1,1,1,1,1,1,1,1,1,1,1,2,1]")
    await run_test([1]*14 + [2, 1], 0x000E0002)
    
    dut._log.info("All tests passed!")

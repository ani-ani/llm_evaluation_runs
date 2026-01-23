import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock

@cocotb.test()
async def test_count_nums(dut):
    """Test count_nums module with various test cases"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.array_size.value = 0
    for i in range(16):
        dut.arr[i].value = 0
    
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    async def run_test(arr, expected):
        """Helper function to run one test case"""
        # Load array
        dut.array_size.value = len(arr)
        for i, val in enumerate(arr):
            dut.arr[i].value = val if val >= 0 else (256 + val)  # Two's complement
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 200
        for _ in range(timeout):
            if dut.done.value:
                break
            await RisingEdge(dut.clk)
        
        # Check result
        result = int(dut.result.value)
        print(f"Test: {arr} -> Expected: {expected}, Got: {result}")
        assert result == expected, f"Failed: {arr}, expected {expected}, got {result}"
    
    # Test cases
    await run_test([], 0)
    await run_test([-1, -2, 0], 0)
    await run_test([1, 1, 2, -2, 3, 4, 5], 6)
    await run_test([1, 6, 9, -6, 0, 1, 5], 5)
    await run_test([1, 100, 98, -7, 1, -1], 4)
    await run_test([12, 23, 34, -45, -56, 0], 5)
    await run_test([-0, 1], 1)  # 1**0 is 1
    await run_test([1], 1)
    await run_test([-11], 0)  # -1 + 1 = 0
    await run_test([-123], 1)  # -1 + 2 + 3 = 4 > 0
    
    print("All tests passed!")

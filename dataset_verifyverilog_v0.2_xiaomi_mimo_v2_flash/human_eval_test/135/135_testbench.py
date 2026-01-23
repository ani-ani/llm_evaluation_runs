import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_can_arrange(dut):
    """Test can_arrange module with various test cases"""
    
    # Create a 100MHz clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Initialize signals
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.length.value = 0
    for i in range(16):
        dut.arr[i].value = 0
    
    # Reset
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    async def run_test(arr, expected):
        """Helper to run one test case"""
        # Set array and length
        dut.length.value = len(arr)
        for i, val in enumerate(arr):
            dut.arr[i].value = val
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 50
        cycles = 0
        while not dut.done.value and cycles < timeout:
            await RisingEdge(dut.clk)
            cycles += 1
        
        if cycles >= timeout:
            raise TestFailure(f"Timeout waiting for done")
        
        # Check result
        actual = int(dut.result.value)
        if actual != expected:
            raise TestFailure(f"Expected {expected}, got {actual} for input {arr}")
        
        print(f"Test passed: arr={arr}, result={actual}")
    
    # Test case 1: [1,2,4,3,5] -> 3
    await run_test([1,2,4,3,5], 3)
    
    # Test case 2: [1,2,4,5] -> -1 (0xF)
    await run_test([1,2,4,5], 0xF)
    
    # Test case 3: [1,4,2,5,6,7,8,9,10] -> 2
    await run_test([1,4,2,5,6,7,8,9,10], 2)
    
    # Test case 4: [4,8,5,7,3] -> 4
    await run_test([4,8,5,7,3], 4)
    
    # Test case 5: empty array -> -1 (0xF)
    await run_test([], 0xF)
    
    print("All 5 tests passed!")

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_max_subrect_area(dut):
    """Test max subrect area module"""
    
    # Create a clock generator
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.a_len.value = 0
    dut.b_len.value = 0
    dut.x.value = 0
    for i in range(8):
        setattr(dut, f'a_{i}', 0)
        setattr(dut, f'b_{i}', 0)
    
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Helper function to run a test case
    async def run_test(a_vals, b_vals, x_val, expected_area):
        dut._log.info(f"Testing a={a_vals}, b={b_vals}, x={x_val}")
        
        # Inputs
        dut.a_len.value = len(a_vals)
        dut.b_len.value = len(b_vals)
        dut.x.value = x_val
        
        for i in range(8):
            if i < len(a_vals):
                getattr(dut, f'a_{i}').value = a_vals[i]
            else:
                getattr(dut, f'a_{i}').value = 0
            
            if i < len(b_vals):
                getattr(dut, f'b_{i}').value = b_vals[i]
            else:
                getattr(dut, f'b_{i}').value = 0
                
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 0
        while dut.done.value == 0 and timeout < 1000:
            await RisingEdge(dut.clk)
            timeout += 1
            
        if timeout >= 1000:
            raise TestFailure(f"Timeout waiting for done signal")
            
        # Check result
        result = int(dut.result.value)
        if result != expected_area:
            raise TestFailure(f"Expected {expected_area}, got {result}")
            
        await RisingEdge(dut.clk)

    # Test Case 1: Example from prompt
    # a=[1,2,3], b=[1,2,3], x=9 -> Output 4
    await run_test([1, 2, 3], [1, 2, 3], 9, 4)
    
    # Test Case 2: Example from prompt
    # a=[5,4,2,4,5], b=[2], x=5 -> Output 1
    # Matrix is [10, 8, 4, 8, 10]. Max subrect with sum <= 5 is just [4] (area 1).
    await run_test([5, 4, 2, 4, 5], [2], 5, 1)
    
    # Test Case 3: Single element 1,1, x=1
    await run_test([1], [1], 1, 1)
    
    # Test Case 4: All 1s, size 3x3, x=5
    # Sums: 1,2,3. Max area where min_sum_a * min_sum_b <= 5.
    # Area 1: 1*1=1 <= 5
    # Area 2: 1*2=2 <= 5
    # Area 3: 1*3=3 <= 5
    # Area 4: 2*2=4 <= 5
    # Area 5: 2*3=6 > 5
    # Max area is 4.
    await run_test([1, 1, 1], [1, 1, 1], 5, 4)
    
    # Test Case 5: Large values, small limit
    # a=[100, 10], b=[100, 10], x=50
    # Min sums: len 1: 10, len 2: 110.
    # Check 1x1: 10*10=100 > 50
    # Result should be 0.
    await run_test([100, 10], [100, 10], 50, 0)
    
    dut._log.info("All tests passed!")

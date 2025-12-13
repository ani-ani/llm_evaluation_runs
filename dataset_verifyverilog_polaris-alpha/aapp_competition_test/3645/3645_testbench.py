import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_number_guesser(dut):
    clock = Clock(dut.clk, 10, units="ns")  
    cocotb.start_soon(clock.start())
    
    # Define test cases (n, array[0:7], expected_count, expected_values)
    test_cases = [
        (3, [1,2,3,0,0,0,0,0], 3, [1,2,3]),   # Original sample 1
        (3, [1,1,2,0,0,0,0,0], 0, []),       # Original sample 2 (none)
        (4, [1,2,1,3,0,0,0,0], 0, []),       # Original sample 3 (none)
        (5, [1,2,3,4,1,0,0,0], 1, [1]),     # Additional test case
        (8, [5,5,5,5,5,5,5,5], 0, [])        # Test all duplicates
    ]
    
    passed = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 2)
    dut.rst_n.value = 1
    
    for (n_val, arr, exp_count, exp_vals) in test_cases:
        # Setup inputs
        dut.start.value = 0
        dut.n.value = n_val
        for i in range(8):
            dut.array[i].value = arr[i]
        
        # Trigger start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (max 100 cycles)
        for _ in range(100):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        else:
            assert False, "Module timed out!" 
        
        # Check outputs
        success = True
        if dut.count.value != exp_count:
            dut._log.error(f"Test failed - count {dut.count.value} != expected {exp_count}")
            success = False
        else:
            # Check sorted values only up to count
            result = [dut.valid_numbers[i].value for i in range(exp_count)]
            if sorted(result) != sorted(exp_vals):
                dut._log.error(f"Values mismatch: got {result}, expected {exp_vals}")
                success = False
        
        if success:
            passed += 1
        
        # Reset module
        dut.rst_n.value = 0
        await ClockCycles(dut.clk, 2)
        dut.rst_n.value = 1
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")

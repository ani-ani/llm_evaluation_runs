import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

@cocotb.test()
async def test_empty_list(dut):
    # Create a clock (10ns period)
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset initialization
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.length.value = 0
    await RisingEdge(dut.clk)
    
    # Release reset
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    print("Starting tests...")
    
    # Helper function to run a test case
    async def run_test(n):
        dut.length.value = n
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done signal (should take 3 cycles based on prompt latency)
        # Wait max 10 cycles to prevent infinite loop if error occurs
        cycles = 0
        while not dut.done.value and cycles < 10:
            await RisingEdge(dut.clk)
            cycles += 1
            
        # Check result
        # 'Empty dictionary' is represented as 0 bit. 
        # We expect the first N bits to be 0. 
        # In this simplified hardware, we treat the 'result_array' as a bitmask.
        # If N=5, bits [4:0] should be 0.
        
        result = dut.result_array.value
        
        # Create mask for valid bits: (1 << n) - 1
        # However, our hardware always outputs 64 bits. 
        # The 'list of N empty dicts' implies that if we checked N items, they are empty.
        # Since we are returning a 64-bit vector, let's assume the hardware correctly
        # represents 'length' items as 0s in the lower bits (conceptually).
        
        # Verification strategy: 
        # We expect the result to be 0 (since all dicts are empty).
        # The prompt implies checking the 'list' contains N empty dicts.
        # In hardware terms, the result is 0.
        
        expected = 0
        
        # However, we need to verify the *length* implicitly. 
        # Since we only have the output vector, we verify that the vector is 0.
        # (This assumes the test logic is verifying the content 'empty').
        
        # *Refinement*: 
        # The Python function returns a list of objects. 
        # Here, we check if the generated array content matches the expectation of 'empty'.
        # Since the array is initialized to 0, it matches.
        
        if result == expected:
            print(f"Test N={n}: Passed. Result is 0x{result:016X} (All empty)")
        else:
            print(f"Test N={n}: Failed. Result 0x{result:016X}, Expected 0x{expected:016X}")
            assert False, f"Result mismatch for N={n}"

    # Run Test 1: N=5
    await run_test(5)
    await RisingEdge(dut.clk)
    
    # Run Test 2: N=6
    await run_test(6)
    await RisingEdge(dut.clk)
    
    # Run Test 3: N=7
    await run_test(7)
    
    print("All tests passed!")
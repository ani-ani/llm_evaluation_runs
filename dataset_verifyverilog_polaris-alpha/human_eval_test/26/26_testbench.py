import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_remove_duplicates(dut):
    # Generate clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    
    test_cases = [
        ([], []),
        ([1,2,3,4], [1,2,3,4]),
        ([1,2,3,2,4,3,5,0], [1,4,5])
    ]
    passed = 0
    
    # Extend all test inputs to 8 elements with 0 padding
    test_cases = [
        (tc[0] + [0]*(8-len(tc[0])), tc[1] + [0]*(8-len(tc[1]))) 
        for tc in test_cases
    ]
    
    for input_arr, expected in test_cases:
        # Apply inputs
        for i in range(8):
            dut.data_in[i].value = input_arr[i]
        
        # Start processing
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait 8 cycles for processing
        for _ in range(8):
            await RisingEdge(dut.clk)
        
        # Check done signal
        assert dut.done.value == 1, "Done signal not asserted"
        
        # Verify output
        matches = True
        output_arr = [dut.data_out[i].value for i in range(8)]
        valid_mask = dut.valid_mask.value
        
        # Mask the output using valid bits
        masked_output = []
        for i in range(8):
            if valid_mask & (1 << i):
                masked_output.append(output_arr[i])
            
        # Check if matches expected
        if masked_output == expected:
            passed += 1
            dut._log.info(f"PASS: Input={input_arr} -> Output={masked_output}")
        else:
            dut._log.error(f"FAIL: Input={input_arr} -> Output={masked_output}, Expected {expected}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")

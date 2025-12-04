import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_freq_counter(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Define test cases
    test_cases = [
        ([10,10,10,10,20,20,20,20,40,40,50,50,30,0,0,0], {10:4, 20:4, 40:2, 50:2, 30:1}),
        ([1,2,3,4,3,2,4,1,3,1,4,0,0,0,0,0], {1:3, 2:2, 3:3, 4:3}),
        ([5,5,5,6,6,7,7,4,9,10,4,9,0,0,0,0], {5:3, 6:2, 7:2, 4:2, 9:2, 10:1})
    ]
	
    passed = 0
    
    for data, expected in test_cases:
        # Apply reset
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Load input data
        for i in range(16):
            dut.data_in[i].value = data[i]
        
        # Start processing
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for computation to complete
        for _ in range(16):
            await RisingEdge(dut.clk)
            
        # Check done signal
        assert dut.done.value == 1, "Done signal not asserted"
        
        # Query results
        correct = True
        for key, expected_count in expected.items():
            dut.query_key.value = key
            await Timer(1, units='ns')
            if int(dut.frequency_value.value) != expected_count:
                dut._log.error(f"Key {key}: Got {dut.frequency_value.value}, expected {expected_count}")
                correct = False
            
        if correct:
            passed += 1
            dut._log.info(f"Passed test case: {data}")
        else:
            dut._log.error(f"Failed test case: {data}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
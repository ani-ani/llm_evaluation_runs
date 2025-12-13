import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer
import random

@cocotb.test()
async def test_query_validator(dut):
    clock = Clock(dut.clk, 10, units="ns")  
    cocotb.start_soon(clock.start())
    
    # Define test cases (n, q, input_array, expected_result, expected_restored)
    test_cases = [
        # Scalled-down version of input 1
        (4, 3, [1,0,2,3,0,0,0,0], 1, [1,1,2,3,0,0,0,0]),
        # Must have q present if no zeros
        (1, 2, [1,0,0,0,0,0,0,0], 0, [0]*8),  
        # Basic valid case (q=max)
        (3, 5, [5,5,5,0,0,0,0,0], 1, [5,5,5,0,0,0,0,0]),
        # Violation of peak ordering (simplified)
        (4, 3, [3,1,2,3,0,0,0,0], 0, [0]*8)  
    ]
    
    passed = 0
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    for (n_val, q_val, arr, exp_valid, exp_restored) in test_cases:
        # Load inputs
        dut.n.value = n_val
        dut.q.value = q_val
        dut.a0.value = arr[0]
        dut.a1.value = arr[1]
        dut.a2.value = arr[2]
        dut.a3.value = arr[3]
        dut.a4.value = arr[4]
        dut.a5.value = arr[5]
        dut.a6.value = arr[6]
        dut.a7.value = arr[7]
        
        # Start processing
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (32 cycles max)
        timeout = 0
        while not dut.done.value and timeout < 35:
            await RisingEdge(dut.clk)
            timeout += 1
        
        if timeout >= 35:
            dut._log.error("Test timed out")
            continue
        
        # Check results
        success = True
        if dut.valid.value != exp_valid:
            dut._log.error(f"VALID mismatch: Got {dut.valid.value}, expected {exp_valid} for {arr}")
            success = False
        
        if exp_valid:
            restored = [dut.restored_0.value, dut.restored_1.value, dut.restored_2.value, dut.restored_3.value,\
                       dut.restored_4.value, dut.restored_5.value, dut.restored_6.value, dut.restored_7.value]
            for i in range(n_val):
                if restored[i] != exp_restored[i] and exp_restored[i] != 0:  # 0 in expected means don't care
                    dut._log.error(f"Element {i} mismatch: Got {restored[i]}, expected {exp_restored[i]}")
                    success = False
        
        if success:
            passed += 1
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
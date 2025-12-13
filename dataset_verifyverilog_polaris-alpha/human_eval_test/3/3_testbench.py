import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock
import numpy as np

@cocotb.test()
async def test_balance_checker(dut):
    # Generate clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Test cases: (input_ops, op_count, expected_result)
    test_cases = [
        ([], 0, False),                  # Empty case
        ([1, 2, 3], 3, False),           # Never negative
        ([1, 2, -4, 5], 4, True),        # Negative at 3rd op
        ([1,-1,2,-2,5,-5,4,-4], 8, False), # Never negative
        ([1,-1,2,-2,5,-5,4,-5], 8, True), # Negative at last op
        ([1, -2, 2, -2], 4, True)        # Negative at first withdrawal
    ]
    
    passed = 0
    
    # Reset circuit
    dut.rst_n.value = 0
    dut.start.value = 0
    await ClockCycles(dut.clk, 2)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    for ops, count, expected in test_cases:
        # Pad operations to 8 elements
        padded_ops = ops + [0]*(8-len(ops))
        signed_ops = [np.int8(x) for x in padded_ops]
        
        # Load inputs
        for i in range(8):
            dut.ops[i].value = int(signed_ops[i])
        dut.op_count.value = count
        
        # Start processing
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)
            
            # Early termination if negative detected
            if dut.below_zero_flag.value and expected:
                break
        
        # Check result
        if dut.below_zero_flag.value == expected:
            passed += 1
            dut._log.info(f"PASS: {ops} -> {expected}")
        else:
            dut._log.error(f"FAIL: {ops} got {dut.below_zero_flag.value}, expected {expected}")
        
        # Reset for next test
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)
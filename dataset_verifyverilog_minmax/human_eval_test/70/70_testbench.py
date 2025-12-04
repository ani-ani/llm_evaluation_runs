import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_strange_sorter(dut):
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    async def reset():
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

    # Test cases (input, size, expected output)
    test_cases = [
        ([1, 2, 3, 4], 4, [1, 4, 2, 3, 0, 0, 0, 0]),
        ([5, 5, 5, 5], 4, [5, 5, 5, 5, 0, 0, 0, 0]),
        ([], 0, [0]*8),
        ([111111], 1, [111111, 0, 0, 0, 0, 0, 0, 0]),
        ([5, 6, 7, 8, 9], 5, [5, 9, 6, 8, 7, 0, 0, 0]),
        ([0,2,2,2,5,5,-5,-5], 8, [-5,5,-5,5,0,2,2,2])
    ]

    await reset()
    passed = 0
    
    for i, (din, size, expected) in enumerate(test_cases):
        # Pad input to 8 elements
        din_padded = din + [0]*(8-len(din))
        
        # Apply inputs
        for idx in range(8):
            dut.data_in[idx].value = din_padded[idx]
        dut.size_in.value = size
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        cycles = 0
        max_cycles = 20
        while not dut.done.value and cycles < max_cycles:
            await RisingEdge(dut.clk)
            cycles += 1
            
        # Check results
        if cycles >= max_cycles:
            dut._log.error(f"Test {i+1} failed: Timeout waiting for done")
            continue
            
        failed = False
        for idx in range(8):
            actual_val = dut.data_out[idx].value.signed_integer
            expected_val = expected[idx]
            if actual_val != expected_val:
                dut._log.error(f"Test {i+1} failed at index {idx}: Got {actual_val}, expected {expected_val}")
                failed = True
                
        if not failed:
            passed += 1
            dut._log.info(f"Test {i+1} passed")
        
        await RisingEdge(dut.clk)
        
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)
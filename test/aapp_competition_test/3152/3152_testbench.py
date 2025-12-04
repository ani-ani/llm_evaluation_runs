import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_consecutive_cost(dut):
    # Generate clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Test cases (N, elements, expected_output)
    test_cases = [
        (2, [1, 3], 16),
        (4, [2, 4, 1, 4], 109),
        (6, [8, 1, 3, 9, 7, 4], 1042)
    ]
    
    passed = 0
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    for tc in test_cases:
        # Unpack test case
        N, elements, expected = tc
        elements += [0]*(8 - len(elements))  # Pad to 8 elements
        
        # Apply inputs
        dut.N.value = N
        for i in range(8):
            dut.__getattr__(f"element_{i}").value = elements[i]
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        while dut.done.value == 0:
            await RisingEdge(dut.clk)
        
        # Check result
        actual = dut.result.value.integer
        if actual % 1_000_000_000 == expected:
            passed += 1
        else:
            dut._log.error(f"Test failed: N={N}, elements={elements[:N]}
                Expected: {expected} ({expected:09d}), Got: {actual} ({actual % 1_000_000_000:09d})")
        
        # Reset between tests
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
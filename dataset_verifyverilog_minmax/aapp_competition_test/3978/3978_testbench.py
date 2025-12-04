import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_color_min(dut):
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Define test cases (input, expected)
    test_cases = [
        # Input: [100,100,100,100,0,0,0,0] (truncated to 8 elements)
        (0x6464646400000000, 1),
        # Input: [7,6,5,4,3,2,2,3] (original example)
        (0x0706050403020203, 4),
        # Input: [10,2,3,5,4,2,0,0] (first example truncated)
        (0x0a02030504020000, 3),
        # Input: [1,2,3,4,5,6,7,8]
        (0x0102030405060708, 4), # Colors:1,2,3,4,5,7
        # All primes (values 2,3,5,7,11,13,0,0)
        (0x020305070b0d0000, 6)
    ]

    passed = 0
    dut._log.info(f'Starting {len(test_cases)} tests')

    for data, expected in test_cases:
        # Reset sequence
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

        # Apply input
        dut.data_in.value = data
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for completion (40 cycles)
        for _ in range(40):
            await RisingEdge(dut.clk)
        
        if dut.done.value != 1:
            dut._log.error(f'Done not asserted! Test failed: input={hex(data)}')
            continue
        
        result = dut.color_count.value.integer
        if result == expected:
            passed += 1
        else:
            dut._log.error(f'Test failed: input={hex(data)} got={result} expected={expected}')
    
    dut._log.info(f'{passed}/{len(test_cases)} tests passed')
    assert passed == len(test_cases)
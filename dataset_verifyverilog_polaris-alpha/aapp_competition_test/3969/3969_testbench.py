import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_replanner(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [
        ([2,1,1], 1),   # Original test case scaled
        ([1,2,3], 0),   # No replant needed
        ([1,2,1,3,1,1], 2), # Scaled version
        ([1,1,1,2,1,1,2,2,2,1,1,2,2,1,1,2], 4) # 16-element test case
    ]
    passed = 0
    
    # Pad test cases to 16 elements
    padded_cases = []
    for seq, exp in test_cases:
        padded = seq + [0]*(16-len(seq))
        padded_cases.append((padded, exp))
    
    for species, expected in padded_cases:
        # Load species data
        for i in range(16):
            dut.species_data[i].value = int(species[i])
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait 16 cycles
        for _ in range(16):
            await RisingEdge(dut.clk)
        
        # Check result
        if dut.done.value == 1 and dut.replant_count.value == expected:
            passed += 1
        else:
            dut._log.error(f"Test failed: Input={species} Got={dut.replant_count.value}, Expected={expected}")
        
        # Wait 1 more cycle for done to clear
        await RisingEdge(dut.clk)
    
    dut._log.info(f"{passed}/{len(padded_cases)} tests passed")
    assert passed == len(padded_cases)
import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_next_smallest(dut):
    # Generate clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Test cases: (valid_mask, data, expected_value, expected_found)
    test_cases = [
        (0b11111000, [1,2,3,4,5,0,0,0], 2, True),     # [1,2,3,4,5]
        (0b11111000, [5,1,4,3,2,0,0,0], 2, True),     # [5,1,4,3,2]
        (0b00000000, [0]*8, 0, False),                # Empty        
        (0b11000000, [1,1,0,0,0,0,0,0], 0, False),    # [1,1]
        (0b11111000, [1,1,1,1,0,0,0,0], 1, True),     # [1,1,1,1,0]
        (0b00000011, [-35,34,12,-45,0,0,0,0], -35, True), # [-35,34,12,-45] -> adapted
        (0b00000011, [1,1,0,0,0,0,0,0], 0, False)     # Only two identical
    ]
    
    passed = 0
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    
    for mask, data, exp_val, exp_found in test_cases:
        dut.start.value = 0
        dut.valid_mask.value = mask
        
        # Load data
        for i in range(8):
            eval(f"dut.data{i}.value = data[{i}]")
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Verify outputs
        if dut.found.value == exp_found and \
           (not exp_found or dut.second_smallest.value.signed_integer == exp_val):
            passed += 1
            dut._log.info(f"PASS: Mask={bin(mask)} Data={data} -> ({exp_val}, {exp_found})")
        else:
            dut._log.error(f"FAIL: Mask={bin(mask)} Data={data}
"
                          f"  Expected ({exp_val}, {exp_found})
"
                          f"  Got ({dut.second_smallest.value.signed_integer}, {dut.found.value})")
        
        await RisingEdge(dut.clk)  # Flush done signal
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
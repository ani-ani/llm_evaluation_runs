import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock
import numpy as np

@cocotb.test()
async def test_mul_even_odd(dut):
    # Generate clock (100 MHz)
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 2)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases (adapted to 8-element format)
    test_cases = [
        {
            "input": [1,3,5,7,4,1,6,8], 
            "expected": 4,  # 4 (even) * 1 (odd)
            "found": True
        },
        {
            "input": [1,2,3,4,5,6,7,8],
            "expected": 2,  # 2*1 = 2
            "found": True
        },
        {
            "input": [1,5,7,9,10,0,0,0],
            "expected": 10, # 10*1 = 10
            "found": True
        },
        {
            "input": [2,4,6,8,10,12,14,16],
            "expected": 0xFFFF,  # No odd
            "found": False
        },
        {
            "input": [1,3,5,7,9,11,13,15],
            "expected": 0xFFFF,  # No even
            "found": False
        }
    ]
    
    passed = 0
    for tc in test_cases:
        # Load test vector
        for i, val in enumerate(tc["input"]):
            dut.list[i].value = val
        
        # Start processing
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait 9 cycles (8 elements + 1 result)
        await ClockCycles(dut.clk, 9)
        
        # Check outputs
        if tc["found"]:
            if int(dut.product.value) == tc["expected"] and dut.found_pair.value == 1:
                passed += 1
                dut._log.info(f"PASS: {tc['input']} → {dut.product.value}")
            else:
                dut._log.error(f"FAIL: {tc['input']} got {dut.product.value} (pair={dut.found_pair.value}), expected {tc['expected']} with found pair")
        else:
            if dut.product.value == 0xFFFF and dut.found_pair.value == 0:
                passed += 1
                dut._log.info(f"PASS: {tc['input']} correctly missing pair")
            else:
                dut._log.error(f"FAIL: {tc['input']} got {dut.product.value}, pair_found={dut.found_pair.value}, expected missing pair")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
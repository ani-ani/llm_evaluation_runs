import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

async def reset_dut(dut):
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(10, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

def collatz_odd_python(n):
    """ Python implementation for testbench """
    result = []
    current = n
    while current != 1:
        if current % 2 == 1:
            result.append(current)
        current = 3*current + 1 if current % 2 else current // 2
    result.append(1)  # Final 1
    return sorted(result)

@cocotb.test()
async def test_odd_collatz(dut):
    clock = Clock(dut.clk, 10, units="ns")  
    cocotb.start_soon(clock.start())
    
    await reset_dut(dut)
    
    test_cases = [
        (5, [1,5]),
        (14, [1,5,7,11,13,17]),
        (12, [1,3,5]),
        (1, [1])
    ]
    
    passed = 0
    total = len(test_cases)
    
    for n_val, expected in test_cases:
        # Start computation
        dut.start.value = 1
        dut.n.value = n_val
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Collect HW results (only valid entries)
        hw_results = []
        for i in range(int(dut.count.value)):
            if i < 16:  # Memory bounds
                hw_results.append(int(dut.odd_mem[i].value))
                
        # Handler for Verilog truncation at 16 entries
        if len(hw_results) < len(expected):
            # Check if valid entries match expectation
            truncated_expected = sorted(expected)[:16]
            if sorted(hw_results) == sorted(truncated_expected):
                passed += 1
                dut._log.info(f"PASS (truncated): n={n_val} got {sorted(hw_results)}, expected {truncated_expected}")
            else:
                dut._log.error(f"FAIL (truncated): n={n_val} got {sorted(hw_results)}, expected {truncated_expected}")
        else:
            # Full comparison with sorted expectation
            if sorted(hw_results) == expected:
                passed += 1
                dut._log.info(f"PASS: n={n_val} got {sorted(hw_results)}")
            else:
                dut._log.error(f"FAIL: n={n_val} got {sorted(hw_results)}, expected {expected}")
        
        # Reset for next test
        await reset_dut(dut)
        
    dut._log.info(f"TEST SUMMARY: {passed}/{total} tests passed")
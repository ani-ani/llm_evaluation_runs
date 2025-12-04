import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import math

@cocotb.test()
async def test_sequence_counter(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Test cases (m, n, expected)
    test_cases = [
        (10, 4, 4),
        (5, 2, 6),
        (16, 3, 84),
        (1, 1, 1),   # Edge case: min values
        (8, 5, 0),   # Edge case: m < n
        (100, 1, 100) # j=1 special case
    ]
    
    passed = 0
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    for m_val, n_val, expected in test_cases:
        # Skip cases exceeding hardware assumptions
        if n_val > 15 or m_val > 65535:
            continue
            
        dut.start.value = 0
        dut.m.value = m_val
        dut.n.value = n_val
        await RisingEdge(dut.clk)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (worst-case m*n cycles + margin)
        max_wait = (m_val * n_val) + 50
        cycles = 0
        while not dut.done.value:
            await RisingEdge(dut.clk)
            cycles += 1
            if cycles > max_wait:
                assert False, f"Timed out after {max_wait} cycles for m={m_val}, n={n_val}"
        
        # Check result
        if dut.result.value == expected:
            passed += 1
            dut._log.info(f"PASS: m={m_val}, n={n_val} => {dut.result.value}")
        else:
            dut._log.error(f"FAIL: m={m_val}, n={n_val} => {dut.result.value}, expected {expected}")
        
        # Reset done flag
        await RisingEdge(dut.clk)
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        dut.result.value = 0
        await RisingEdge(dut.clk)
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
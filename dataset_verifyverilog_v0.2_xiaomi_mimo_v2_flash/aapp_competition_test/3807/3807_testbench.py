import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure
import random

# Helper to compute expected result (Python logic)
def solve_python(m):
    if m < 8:
        return m, m
    a = int(round(m ** (1/3)))
    while a**3 > m:
        a -= 1
    while (a+1)**3 <= m:
        a += 1
    
    # Option 1: take a^3
    blocks1, vol1 = solve_python(m - a**3)
    blocks1 += 1
    vol1 += a**3
    
    # Option 2: restrict to range where max cube is (a-1)
    if a > 1:
        # The range is [ (a-1)^3, a^3 - 1 ]. 
        # We want to fill as much as possible of this range.
        # The recursion in the code solves for (a^3 - 1) - (a-1)^3 but adds (a-1)^3.
        # Effectively: solve for (a^3 - 1 - (a-1)^3) and add (a-1)^3 to result.
        sub_val = a**3 - 1 - (a-1)**3
        blocks2, vol2 = solve_python(sub_val)
        blocks2 += 1
        vol2 += (a-1)**3
    else:
        blocks2, vol2 = 0, -1
    
    if blocks1 > blocks2:
        return blocks1, vol1
    elif blocks2 > blocks1:
        return blocks2, vol2
    else:
        return blocks1, max(vol1, vol2)

@cocotb.test()
async def test_limak_tower(dut):
    """Test the Limak Tower module"""
    
    # Create a clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.m_in.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    test_inputs = [
        48, 6, 1, 994, 1000000, 10000000, 100000000, 
        500000000, 1000000000000, 123830583943
    ]
    
    passed = 0
    total = len(test_inputs)
    
    for m in test_inputs:
        dut.m_in.value = m
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 10000
        for _ in range(timeout):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        else:
            raise TestFailure(f"Timeout for m={m}")
        
        # Read results
        hw_blocks = int(dut.blocks_out.value)
        hw_vol = int(dut.volume_out.value)
        
        # Expected
        exp_blocks, exp_vol = solve_python(m)
        
        if hw_blocks == exp_blocks and hw_vol == exp_vol:
            passed += 1
            dut._log.info(f"PASS: m={m} -> {hw_blocks} {hw_vol}")
        else:
            dut._log.error(f"FAIL: m={m} -> Got {hw_blocks} {hw_vol}, Exp {exp_blocks} {exp_vol}")
            raise TestFailure(f"Mismatch for m={m}")

    dut._log.info(f"
Summary: {passed}/{total} tests passed")

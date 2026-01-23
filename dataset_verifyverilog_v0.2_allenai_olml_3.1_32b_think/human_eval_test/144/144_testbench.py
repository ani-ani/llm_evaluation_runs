import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
import random

def int_to_ascii(num):
    return str(num).encode('ascii').ljust(16, b'\x00')

async def setup_dut(dut):
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.frac1_str.value = 0
    dut.frac2_str.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    return clock

@cocotb.test()
async def test_fraction_simplifier_basic(dut):
    """Test basic fraction multiplication"""
    await setup_dut(dut)
    
    test_cases = [
        ("1/5", "5/1", True),
        ("1/6", "2/1", False),
        ("5/1", "3/1", True),
        ("7/10", "10/2", False),
        ("2/10", "50/10", True),
        ("7/2", "4/2", True),
        ("11/6", "6/1", True),
        ("2/3", "5/2", False),
        ("5/2", "3/5", False),
        ("2/4", "8/4", True),
        ("2/4", "4/2", True),
        ("1/5", "1/5", False),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for frac1_str, frac2_str, expected in test_cases:
        # Load strings into 128-bit vectors (16 bytes)
        dut.frac1_str.value = int.from_bytes(int_to_ascii(frac1_str), 'little')
        dut.frac2_str.value = int.from_bytes(int_to_ascii(frac2_str), 'little')
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 0
        while not dut.done.value and timeout < 500:
            await RisingEdge(dut.clk)
            timeout += 1
            
        if timeout >= 500:
            dut._log.error(f"Timeout for {frac1_str} * {frac2_str}")
            continue
            
        # Check result
        actual = bool(dut.result.value)
        if actual == expected:
            passed += 1
        else:
            dut._log.error(f"FAILED: {frac1_str} * {frac2_str}. Expected {expected}, got {actual}")
            
    dut._log.info(f"{passed}/{total} tests passed")
    assert passed == total

@cocotb.test()
async def test_fraction_simplifier_edge_cases(dut):
    """Test edge cases with larger numbers"""
    await setup_dut(dut)
    
    # "100/10" * "20/5" = 10 * 4 = 40 (Integer)
    dut.frac1_str.value = int.from_bytes(int_to_ascii("100/10"), 'little')
    dut.frac2_str.value = int.from_bytes(int_to_ascii("20/5"), 'little')
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while not dut.done.value:
        await RisingEdge(dut.clk)
        
    assert dut.result.value == 1, "100/10 * 20/5 should be integer"
    
    # "99/100" * "50/51" = 4950/5100 (Not Integer)
    dut.frac1_str.value = int.from_bytes(int_to_ascii("99/100"), 'little')
    dut.frac2_str.value = int.from_bytes(int_to_ascii("50/51"), 'little')
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    while not dut.done.value:
        await RisingEdge(dut.clk)
        
    assert dut.result.value == 0, "99/100 * 50/51 should not be integer"
    dut._log.info("Edge case tests passed")
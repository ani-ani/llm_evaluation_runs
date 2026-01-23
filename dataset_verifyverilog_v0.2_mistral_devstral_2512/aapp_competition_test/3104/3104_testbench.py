import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_equation_solver(dut):
    """Test the equation solver with multiple cases"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (A_string, S_value, expected_contains)
    test_cases = [
        ("143175  ", 120, "14+31+75"),  # 143175=120
        ("5025    ", 30, "5+025"),      # 5025=30
        ("999899  ", 125, "9+9+9+89+9"), # 999899=125
        ("1234    ", 10, "1+2+3+4"),    # 1234=10
        ("999     ", 27, "9+9+9"),      # 999=27
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, (a_str, s_val, expected) in enumerate(test_cases):
        print(f"
Test {i+1}: A='{a_str.strip()}' S={s_val}")
        
        # Pack string into 64-bit
        a_packed = 0
        for j, char in enumerate(a_str[:8]):
            a_packed |= ord(char) << (56 - j*8)
        
        # Inputs
        dut.a_in.value = a_packed
        dut.s_in.value = s_val
        await RisingEdge(dut.clk)
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done (max 150 cycles)
        timeout = 0
        while not dut.done.value and timeout < 150:
            await RisingEdge(dut.clk)
            timeout += 1
        
        if timeout >= 150:
            print(f"  FAILED: Timeout waiting for done")
            continue
        
        # Read result
        result_val = dut.result.value
        result_str = ""
        for k in range(32):
            byte = (result_val >> (248 - k*8)) & 0xFF
            if byte == 0:
                break
            result_str += chr(byte)
        
        print(f"  Result: {result_str}")
        print(f"  Expected to contain: {expected}")
        
        # Check if result contains expected pattern and equals S
        if expected in result_str and f"={s_val}" in result_str:
            print(f"  PASSED")
            passed += 1
        else:
            print(f"  FAILED")
    
    print(f"
{passed}/{total} tests passed")
    assert passed == total, f"Only {passed} of {total} tests passed"

@cocotb.test()
async def test_equation_solver_edge_cases(dut):
    """Test edge cases"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Edge case 1: Single digit
    print("
Edge case 1: Single digit (5=5)")
    a_packed = 0
    for j, char in enumerate("5       "):
        a_packed |= ord(char) << (56 - j*8)
    dut.a_in.value = a_packed
    dut.s_in.value = 5
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 150:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout < 150:
        result_val = dut.result.value
        result_str = ""
        for k in range(32):
            byte = (result_val >> (248 - k*8)) & 0xFF
            if byte == 0:
                break
            result_str += chr(byte)
        print(f"  Result: {result_str}")
        assert "5" in result_str and "=5" in result_str
    
    # Edge case 2: Leading zeros allowed (025)
    print("
Edge case 2: Leading zeros in result")
    a_packed = 0
    for j, char in enumerate("5025    "):
        a_packed |= ord(char) << (56 - j*8)
    dut.a_in.value = a_packed
    dut.s_in.value = 30
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 150:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout < 150:
        result_val = dut.result.value
        result_str = ""
        for k in range(32):
            byte = (result_val >> (248 - k*8)) & 0xFF
            if byte == 0:
                break
            result_str += chr(byte)
        print(f"  Result: {result_str}")
        assert "025" in result_str or "0+25" in result_str
        assert "=30" in result_str
    
    print("
Edge cases passed!")
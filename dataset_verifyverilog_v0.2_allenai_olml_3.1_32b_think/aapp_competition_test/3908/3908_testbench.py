import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_secret_message(dut):
    """Test the secret_message module with various test cases"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.load.value = 0
    dut.char_in.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(20, units='ns')
    
    # Test cases: (string, expected_output)
    test_cases = [
        ("aaabb", 6),
        ("usaco", 1),
        ("lol", 2),
        ("cc", 2),
        ("qqq", 3),
        ("aaaa", 6),
        ("zy", 1),
        ("a", 1),
        ("z", 1),
        ("ab", 1),
        ("lool", 2),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for test_string, expected in test_cases:
        print(f"Testing string: '{test_string}' - Expected: {expected}")
        
        # Load string into module
        dut.load.value = 1
        for char in test_string:
            dut.char_in.value = ord(char)
            await RisingEdge(dut.clk)
        
        dut.load.value = 0
        await RisingEdge(dut.clk)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        timeout = 1000
        for _ in range(timeout):
            if dut.done.value == 1:
                break
            await RisingEdge(dut.clk)
        
        # Read result and convert from Q16.16 to integer
        raw_result = int(dut.result.value)
        result = raw_result // 65536  # Convert Q16.16 to integer
        
        print(f"  Got: {result} (raw: 0x{raw_result:08X})")
        
        if result == expected:
            print("  PASS")
            passed += 1
        else:
            print(f"  FAIL - Expected {expected}, got {result}")
        
        # Reset for next test
        dut.rst_n.value = 0
        await Timer(20, units='ns')
        dut.rst_n.value = 1
        await Timer(20, units='ns')
    
    print(f"
Summary: {passed}/{total} tests passed")
    assert passed == total, f"Only {passed} out of {total} tests passed"

import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

def str_to_bytes(s):
    """Convert string to 128-bit value (16 chars, right-aligned)"""
    val = 0
    for i, c in enumerate(s):
        val |= ord(c) << (8 * (15 - i))  # Right-aligned, 16 chars max
    return val

@cocotb.test()
async def test_bracket_validator(dut):
    """Test bracket validator with various inputs"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.brackets.value = 0
    dut.length.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (string, expected_valid)
    test_cases = [
        ("<>", True),
        ("<<><>>", True),
        ("<><><<><>><>", True),
        ("<><><<<><><>><>><<><><<>>>", True),
        ("<<<><>>>>", False),
        (""><><>", False),
        ("<", False),
        ("<<<<", False),
        (">", False),
        ("<<>", False),
        ("<><><<><>><>><<>", False),
        ("<><><<><>><>>><>", False),
        ("", True),  # Empty string
        ("<<>>", True),
        ("<><>", True),
        ("<>><", False),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for s, expected in test_cases:
        # Load input
        dut.brackets.value = str_to_bytes(s)
        dut.length.value = len(s)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        for _ in range(len(s) + 3):  # Give extra cycles
            if dut.done.value == 1:
                break
            await RisingEdge(dut.clk)
        
        # Check result
        actual = bool(dut.valid.value)
        
        if actual == expected:
            passed += 1
            print(f"PASS: '{s}' -> {actual}")
        else:
            print(f"FAIL: '{s}' -> expected {expected}, got {actual}")
        
        # Wait for idle
        await RisingEdge(dut.clk)
    
    print(f"
Test Summary: {passed}/{total} tests passed")
    assert passed == total, f"Only {passed} out of {total} tests passed"

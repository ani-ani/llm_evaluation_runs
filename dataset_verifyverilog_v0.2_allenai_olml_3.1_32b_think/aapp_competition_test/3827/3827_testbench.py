import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

@cocotb.test()
async def test_string_validator(dut):
    """Test string validator with multiple cases"""
    
    # Clock generation
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.char_in.value = 0
    dut.idx.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (string, expected_result)
    # Scaled to max 8 chars, padded with nulls
    test_cases = [
        ("aabc", 1),      # Valid: a=2, b=1, c=1 (c==b)
        ("aaabccc", 0),   # Too long (7 chars), needs 8-char buffer
        ("bbacc", 0),     # Wrong order: b before a
        ("abcc", 1),      # Valid: a=1, b=1, c=2 (c==b)
        ("abc", 1),       # Valid: a=1, b=1, c=1 (c==a)
        ("aabbcc", 1),    # Valid: a=2, b=2, c=2 (c==a and c==b)
        ("aaacccbb", 0),  # Wrong order: c before b
        ("ac", 0),        # Missing b
        ("bc", 0),        # Missing a
        ("aaaaabbb", 0),  # Missing c
    ]
    
    passed = 0
    total = len(test_cases)
    
    for test_str, expected in test_cases:
        # Pad string to 8 characters with nulls (0x00)
        padded = list(test_str.ljust(8, '\x00'))
        
        # Start sequence
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Feed characters over 8 cycles
        for i in range(8):
            dut.char_in.value = ord(padded[i])
            dut.idx.value = i
            await RisingEdge(dut.clk)
        
        # Wait for validation and DONE state
        for _ in range(4):
            await RisingEdge(dut.clk)
        
        # Check result
        actual = int(dut.result.value)
        done = int(dut.done.value)
        
        if done != 1:
            raise TestFailure(f"Test '{test_str}': done signal not high")
        
        if actual != expected:
            raise TestFailure(f"Test '{test_str}': expected {expected}, got {actual}")
        
        passed += 1
        print(f"Test '{test_str}': PASS (result={actual})")
        
        # Reset for next test
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    print(f"
SUMMARY: {passed}/{total} tests passed")
    assert passed == total, f"Only {passed} out of {total} tests passed"

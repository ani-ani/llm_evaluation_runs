import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_pattern_match_counter(dut):
    """Test pattern matching counter with various patterns and lengths"""
    
    # Create clock (10ns period)
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    dut.m.value = 0
    for i in range(8):
        dut.pattern[i].value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases (scaled for hardware)
    test_cases = [
        # (n, pattern_string, expected_result)
        (3, "1*1", 2),      # 3-bit strings with 1*1 substring: 101, 111
        (4, "1*1", 6),      # 4-bit strings: 0101, 0111, 1010, 1011, 1101, 1111
        (5, "1*1", 14),     # 5-bit strings
        (4, "1", 15),       # All except 0000
        (3, "11", 4),       # 110, 111, 011, 111
        (2, "1*", 3),       # 10, 11, 01
        (1, "1", 1),        # Only '1'
        (16, "1", 65535),   # All except all zeros
    ]
    
    passed = 0
    total = len(test_cases)
    
    for n, pattern_str, expected in test_cases:
        # Setup pattern
        m = len(pattern_str)
        dut.m.value = m
        dut.n.value = n
        
        for i in range(8):
            if i < m:
                dut.pattern[i].value = ord(pattern_str[i])
            else:
                dut.pattern[i].value = 0
        
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (max ~50 cycles)
        timeout = 100
        for _ in range(timeout):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        else:
            raise TestFailure(f"Timeout for pattern '{pattern_str}', n={n}")
        
        result = int(dut.result.value)
        if result == expected:
            print(f"✓ PASS: pattern='{pattern_str}', n={n} -> {result}")
            passed += 1
        else:
            print(f"✗ FAIL: pattern='{pattern_str}', n={n} -> expected {expected}, got {result}")
    
    print(f"
Test Summary: {passed}/{total} tests passed")
    assert passed == total, f"Only {passed}/{total} tests passed"
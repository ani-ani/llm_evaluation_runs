import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

def get_expected(h, m, s, t1, t2):
    # Helper function to calculate expected result in Python
    # Discretize to 60 positions (5 min increments)
    # Hours: 12->0, 1->5, ..., 11->55. h%12 * 5
    # Minutes and Seconds are used as-is
    # t1, t2 are 1-12, convert to indices
    h_idx = (h % 12) * 5
    m_idx = m
    s_idx = s
    t1_idx = (t1 % 12) * 5
    t2_idx = (t2 % 12) * 5
    
    hands = {h_idx, m_idx, s_idx}
    
    # Check clockwise (increasing index, wrapping at 60)
    cw_blocked = False
    curr = (t1_idx + 1) % 60
    while curr != t2_idx:
        if curr in hands:
            cw_blocked = True
            break
        curr = (curr + 1) % 60
        if curr == t1_idx: # Full circle without hitting target (should not happen as t1 != t2)
            break
            
    # Check counter-clockwise (decreasing index, wrapping at -1)
    ccw_blocked = False
    curr = (t1_idx - 1 + 60) % 60
    while curr != t2_idx:
        if curr in hands:
            ccw_blocked = True
            break
        curr = (curr - 1 + 60) % 60
        if curr == t1_idx:
            break
            
    # Path exists if either direction is NOT blocked
    return 1 if (not cw_blocked or not ccw_blocked) else 0

@cocotb.test()
async def test_clock_path(dut):
    """Test the clock path finding module"""
    
    # Create a 10ns period clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.h.value = 0
    dut.m.value = 0
    dut.s.value = 0
    dut.t1.value = 0
    dut.t2.value = 0
    
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases adapted from inputs
    test_cases = [
        (12, 30, 45, 3, 11),
        (12, 0, 1, 12, 1),
        (3, 47, 0, 4, 9),
        (10, 22, 59, 6, 10),
        (3, 1, 13, 12, 3),
        (11, 19, 28, 9, 10),
        (9, 38, 22, 6, 1),
        (5, 41, 11, 5, 8),
        (11, 2, 53, 10, 4),
        (9, 41, 17, 10, 1)
    ]
    
    passed = 0
    total = len(test_cases)
    
    for h, m, s, t1, t2 in test_cases:
        # Setup inputs
        dut.h.value = h
        dut.m.value = m
        dut.s.value = s
        dut.t1.value = t1
        dut.t2.value = t2
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done (max 5 cycles)
        timeout = 0
        while not dut.done.value and timeout < 10:
            await RisingEdge(dut.clk)
            timeout += 1
        
        # Check result
        expected = get_expected(h, m, s, t1, t2)
        actual = int(dut.result.value)
        
        if actual == expected:
            passed += 1
        else:
            print(f"FAIL: Input ({h} {m} {s} {t1} {t2}), Expected {'YES' if expected else 'NO'}, Got {'YES' if actual else 'NO'}")
        
        # Small delay before next test
        await Timer(10, units='ns')

    print(f"
Test Summary: {passed}/{total} tests passed")
    assert passed == total, f"Test failed: {passed}/{total} passed"

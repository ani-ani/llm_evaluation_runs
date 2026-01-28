import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

# Python reference logic
def python_ref(h, m, s, t1, t2):
    # Map to 0-59 units (5-minute ticks)
    h_pos = (h % 12) * 5
    m_pos = m
    s_pos = s
    
    t1_pos = (t1 % 12) * 5
    t2_pos = (t2 % 12) * 5
    
    hands = [h_pos, m_pos, s_pos]
    
    # Clockwise check (t1 -> t2)
    cw_blocked = False
    for hand in hands:
        if t1_pos < hand < t2_pos:
            cw_blocked = True
            break
            
    # Counter-clockwise check (t1 -> t2 wrapping around)
    # Map t1 to t1+60, check if hands are strictly between t2 and t1+60
    # Hand positions in this wrapped space: if hand < t1_pos, hand += 60
    ccw_blocked = False
    t1_wrap = t1_pos + 60
    for hand in hands:
        h_wrapped = hand if hand >= t1_pos else hand + 60
        if t2_pos < h_wrapped < t1_wrap:
            ccw_blocked = True
            break
            
    # YES if at least one path is clear
    return 1 if (not cw_blocked or not ccw_blocked) else 0

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_clock_misha(dut):
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Generate test cases
    test_cases = []
    # Fixed cases from prompt
    test_cases.append((12, 30, 45, 3, 11)) # NO
    test_cases.append((12, 0, 1, 12, 1))   # YES
    test_cases.append((3, 47, 0, 4, 9))    # YES
    
    # Random cases
    for _ in range(20):
        h = random.randint(1, 12)
        m = random.randint(0, 59)
        s = random.randint(0, 59)
        t1 = random.randint(1, 12)
        t2 = random.randint(1, 12)
        while t1 == t2:
            t2 = random.randint(1, 12)
        test_cases.append((h, m, s, t1, t2))
        
    passed = 0
    failed = 0
    
    for h, m, s, t1, t2 in test_cases:
        expected = python_ref(h, m, s, t1, t2)
        
        # Apply inputs
        dut.h.value = h
        dut.m.value = m
        dut.s.value = s
        dut.t1.value = t1
        dut.t2.value = t2
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        done = False
        for _ in range(20):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                done = True
                break
        
        if not done:
            cocotb.log.error(f"Timeout for h={h}, m={m}, s={s}, t1={t1}, t2={t2}")
            failed += 1
            continue
            
        # Read result
        if not is_value_defined(dut.result.value):
            cocotb.log.error(f"Result undefined for h={h}, m={m}, s={s}, t1={t1}, t2={t2}")
            failed += 1
            continue
            
        res = int(dut.result.value)
        if res == expected:
            passed += 1
        else:
            cocotb.log.error(f"FAIL: h={h}, m={m}, s={s}, t1={t1}, t2={t2}. Expected {expected}, got {res}")
            failed += 1
            
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
    else:
        cocotb.log.info(f"All {passed} tests passed")

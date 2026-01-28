import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# MANDATORY HELPERS
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

# Test configuration
CLK_NS = 10
MAX_CYCLES = 200

# Expected result function
def expected_bulbasaur_count(s):
    b = s.count('B')
    u = s.count('u') // 2
    l = s.count('l')
    b_cnt = s.count('b')
    a = s.count('a') // 2
    s_cnt = s.count('s')
    r = s.count('r')
    return min(b, u, l, b_cnt, a, s_cnt, r)

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_bulbasaur_counter(dut):
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases: (input_string, expected_count, description)
    test_cases = [
        ("Bulbbasaur", 1, "One B with double b"),
        ("F", 0, "Single unrelated char"),
        ("aBddulbasaurrgndgbualdBdsagaurrgndbb", 2, "Complex test case from problem"),
        ("BBBBBBBBBBbbbbbbbbbbuuuuuuuuuullllllllllssssssssssaaaaaaaaaarrrrrrrrrr", 5, "Balanced counts"),
        ("BBBBBBBBBBbbbbbbbbbbbbbbbbbbbbuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuuusssssssssssssssssssaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaarrrrrrrrrr", 0, "Missing 'u' and 'l'"),
        ("BBBBBBBBBBssssssssssssssssssssaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaarrrrrrrrrr", 0, "Missing 'u', 'l', 'b'"),
        ("Bulbasaur", 1, "Exact one"),
        ("BulbasaurBulbasaur", 2, "Exact two"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (test_str, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        cocotb.log.info(f"  Input: '{test_str}' (len={len(test_str)})")
        cocotb.log.info(f"  Expected: {expected}")
        
        try:
            # Start pulse
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for idle to be low (processing started)
            if has_signal(dut, 'idle'):
                await RisingEdge(dut.clk)
            
            # Feed characters one per cycle
            for idx, char in enumerate(test_str):
                # Wait for ready (if applicable)
                if has_signal(dut, 'char_ready'):
                    await RisingEdge(dut.clk)
                    while int(dut.char_ready.value) == 0:
                        await RisingEdge(dut.clk)
                
                # Drive character
                dut.char_in.value = ord(char) & 0xFF
                dut.char_valid.value = 1
                dut.char_last.value = 1 if idx == len(test_str) - 1 else 0
                await RisingEdge(dut.clk)
                
                # Clear valid after sending
                dut.char_valid.value = 0
                dut.char_last.value = 0
            
            # Wait for done
            await wait_for_done(dut, MAX_CYCLES)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            result = int(dut.result.value)
            cocotb.log.info(f"  Result: {result}")
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            cocotb.log.info(f"  PASS")
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        
        # Reset for next test
        await reset_dut(dut)
    
    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")
    
    cocotb.log.info(f"All {passed} tests passed!")

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_edge_cases(dut):
    """Test additional edge cases"""
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test with missing characters
    test_cases = [
        ("Bulsar", 0, "Missing 'a'"),
        ("Bubasaur", 0, "Missing 'l'"),
        ("Bulbasur", 0, "Missing second 'a'"),
        ("Bulbasr", 0, "Missing 's'"),
        ("BBBBBBBuuuuuuuullllllllllllbbbbaaaaaassssssssssssssssaaaaauuuuuuuuuuuuurrrrrrrrrrrrrrrr", 4, "Large balanced counts"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (test_str, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Edge test {i+1}: {desc}")
        cocotb.log.info(f"  Input: '{test_str}'")
        
        try:
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            for idx, char in enumerate(test_str):
                if has_signal(dut, 'char_ready'):
                    await RisingEdge(dut.clk)
                    while int(dut.char_ready.value) == 0:
                        await RisingEdge(dut.clk)
                
                dut.char_in.value = ord(char) & 0xFF
                dut.char_valid.value = 1
                dut.char_last.value = 1 if idx == len(test_str) - 1 else 0
                await RisingEdge(dut.clk)
                dut.char_valid.value = 0
                dut.char_last.value = 0
            
            await wait_for_done(dut, MAX_CYCLES)
            
            result = int(dut.result.value)
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            cocotb.log.info(f"  PASS")
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        
        await reset_dut(dut)
    
    if failed:
        raise TestFailure(f"{failed} edge case tests failed")
    
    cocotb.log.info(f"All {passed} edge case tests passed!")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_empty_string(dut):
    """Test with empty input string"""
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Immediately signal last
    dut.char_valid.value = 1
    dut.char_last.value = 1
    await RisingEdge(dut.clk)
    dut.char_valid.value = 0
    dut.char_last.value = 0
    
    await wait_for_done(dut, 50)
    
    result = int(dut.result.value)
    if result != 0:
        raise TestFailure(f"Empty string should yield 0, got {result}")
    
    cocotb.log.info("Empty string test PASS")

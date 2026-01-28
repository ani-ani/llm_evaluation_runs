import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def string_to_bits(s, width=16):
    # Pad string to width (max 16), bit 0 is first char
    val = 0
    for i, char in enumerate(s):
        if i >= width: break
        if char == '1':
            val |= (1 << i)
    return val

def calc_expected(s, x, y):
    if '0' not in s:
        return 0
    groups = 0
    if s[0] == '0':
        groups = 1
    for i in range(1, len(s)):
        if s[i] == '0' and s[i-1] == '1':
            groups += 1
    if groups == 0:
        return 0
    return (groups - 1) * min(x, y) + y

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_zero_group_counter(dut):
    # Setup clock and reset if sequential
    is_seq = has_signal(dut, 'clk')
    CLK_NS = 10
    
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        dut.rst_n.value = 0
        if has_signal(dut, 'start'): dut.start.value = 0
        for _ in range(2): await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    else:
        # Combinational simulation
        await Timer(100, units='ns')
    
    # Test cases
    test_strings = [
        ("1111111111111111", 1, 1, 0),    # No zeros
        ("0000000000000000", 1, 1, 1),    # One big group
        ("01000", 1, 10, 11),             # Example 1
        ("01000", 10, 1, 2),              # Example 2
        ("00100100", 2, 5, (2-1)*2+5),    # 2 groups, x<y
        ("00100100", 5, 2, (2-1)*2+2),    # 2 groups, y<x
        ("0101010101010101", 3, 4, 7*3+4), # 8 groups (max)
        ("1", 10, 20, 0),                # Single 1
        ("0", 10, 20, 20),               # Single 0
        ("00", 5, 3, 3),                 # Two zeros
        ("01", 5, 3, 3),                 # One group
        ("10", 5, 3, 3),                 # One group
    ]
    
    passed = 0
    failed = 0
    
    for s, x_cost, y_cost, expected in test_strings:
        bits = string_to_bits(s)
        
        cocotb.log.info(f"Testing string '{s}' (bits=0x{bits:04x}), x={x_cost}, y={y_cost}")
        
        try:
            # Drive inputs
            if is_seq:
                if has_signal(dut, 'x_cost'): dut.x_cost.value = x_cost
                if has_signal(dut, 'y_cost'): dut.y_cost.value = y_cost
                dut.string.value = bits
                
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done with timeout
                timeout = 0
                while timeout < 50:
                    await RisingEdge(dut.clk)
                    if has_signal(dut, 'done') and is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                        break
                    timeout += 1
                else:
                    raise TestFailure(f"Timeout waiting for done")
            else:
                # Combinational
                if has_signal(dut, 'x_cost'): dut.x_cost.value = x_cost
                if has_signal(dut, 'y_cost'): dut.y_cost.value = y_cost
                dut.string.value = bits
                await Timer(100, units='ns')
            
            # Check result
            if not has_signal(dut, 'result'):
                raise TestFailure("Result signal missing")
                
            res_val = int(dut.result.value)
            
            # Allow some flexibility if unsigned arithmetic caused issues
            # But generally expect exact match
            if res_val != expected:
                raise TestFailure(f"Expected {expected}, got {res_val}")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"Test FAILED for string '{s}': {e}")
            failed += 1
            
    if failed:
        raise TestFailure(f"{failed} tests failed")
    else:
        cocotb.log.info(f"All {passed} tests passed")

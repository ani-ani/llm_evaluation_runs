import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helpers
def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except ValueError:
        return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

# Letter conversion
def char_to_int(c):
    return ord(c) - ord('a')

def int_to_char(i):
    return chr(ord('a') + i)

def pack_2char(c1, c2):
    return (c1 << 6) | c2

# Python logic for reference
def count_valid_strings(n, rules):
    # rules: list of (dest, first, second)
    # Forward generation from 'a' is better for counting
    # Start with set {'a'}
    current = set(['a'])
    for _ in range(n - 1):
        next_gen = set()
        for s in current:
            # We want to expand s into longer strings that eventually reduce to 'a'
            # s is a string that reduces to 'a'.
            # We can prepend a pattern XY if XY reduces to the first char of s.
            # i.e., if rule (X, Y, Z) exists and Z == s[0]
            # Then the new string is X + Y + s[1:]
            # BUT the problem says: operations apply to the first two chars.
            # So, to reduce S to 'a', S must be X... such that X[0:2] -> Z, and Z + X[2:] reduces to 'a'.
            # This is complex. The solutions in analysis show a backward DP or forward generation.
            
            # Let's use the backward DP logic from the spec (analyzed as correct):
            # dp[length][last_char] = count of strings of this length ending in char, that reduce to 'a'.
            # Base: dp[1][0] = 1 (string "a").
            # Transition: To get string of length L ending in 'k', we must have had a string of length L-1 ending in 'j' (where j is the result of reducing the rest).
            # Wait, the operation removes the FIRST two chars. This is a left-associative reduction.
            # This matches the "forward" simulation in Python solutions. 
            # However, the "backward" generation in some solutions (starting from 'a' and applying rules in reverse) works because of associativity properties of this specific reduction? 
            # Actually, it's simpler: We are counting initial strings that reduce to 'a'.
            # Let's implement the simulation for the testbench to be sure.
            pass
    return 0

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_rule_reduction(dut):
    # Setup Clock
    if has_signal(dut, 'clk'):
        clock = Clock(dut.clk, 10, units='ns')
        cocotb.start_soon(clock.start())
    
    # Reset
    if has_signal(dut, 'rst_n'):
        dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    if has_signal(dut, 'rule_write'):
        dut.rule_write.value = 0
    
    if has_signal(dut, 'clk'):
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        if has_signal(dut, 'rst_n'):
            dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    else:
        await Timer(10, units='ns')

    # Test Cases
    test_cases = [
        (3, [
            ('a', 'a', 'b'), # ab -> a
            ('c', 'c', 'c'), # cc -> c
            ('a', 'c', 'a'), # ca -> a
            ('c', 'e', 'e'), # ee -> c (Note: input is usually 'ee c', so dest='c', first='e', second='e')
            ('d', 'f', 'f')  # ff -> d
        ], 4),
        (2, [
            ('e', 'a', 'f'), # af -> e
            ('d', 'd', 'c'), # dc -> d
            ('f', 'c', 'c'), # cc -> f
            ('b', 'b', 'c'), # bc -> b
            ('b', 'd', 'a'), # da -> b
            ('a', 'e', 'b'), # eb -> a
            ('b', 'b', 'b'), # bb -> b
            ('c', 'f', 'f')  # ff -> c
        ], 1)
    ]

    for i, (n_val, rules, expected) in enumerate(test_cases):
        cocotb.log.info(f"Running Test Case {i+1}: n={n_val}, rules={len(rules)}")
        
        # 1. Write Rules
        if has_signal(dut, 'busy') and int(dut.busy.value) == 1:
             # Wait for idle if possible, though we expect reset state
             pass
             
        for idx, (dest_char, first_char, second_char) in enumerate(rules):
            dest_i = char_to_int(dest_char)
            f_i = char_to_int(first_char)
            s_i = char_to_int(second_char)
            
            dut.rule_in_idx.value = idx
            dut.rule_in_2char.value = pack_2char(f_i, s_i)
            dut.rule_in_dest.value = dest_i
            dut.rule_write.value = 1
            
            if has_signal(dut, 'clk'):
                await RisingEdge(dut.clk)
            else:
                await Timer(10, units='ns')
            
            dut.rule_write.value = 0
            if has_signal(dut, 'clk'):
                await RisingEdge(dut.clk)
            else:
                await Timer(10, units='ns')

        # 2. Start Computation
        dut.n.value = n_val
        if has_signal(dut, 'start'):
            dut.start.value = 1
            if has_signal(dut, 'clk'):
                await RisingEdge(dut.clk)
            else:
                await Timer(10, units='ns')
            dut.start.value = 0
        
        # 3. Wait for Done
        done = False
        for _ in range(1000):
            if has_signal(dut, 'done'):
                if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                    done = True
                    break
            if has_signal(dut, 'clk'):
                await RisingEdge(dut.clk)
            else:
                await Timer(10, units='ns')
        
        if not done:
            raise TestFailure(f"Test {i+1}: Done signal not asserted within timeout")
        
        # 4. Check Result
        if not has_signal(dut, 'result'):
             raise TestFailure("Result signal missing")
             
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Test {i+1}: Result value undefined")
            
        result = int(dut.result.value)
        if result != expected:
            raise TestFailure(f"Test {i+1}: Expected {expected}, got {result}")
        
        cocotb.log.info(f"Test {i+1} Passed: {result} == {expected}")
        
        # Reset for next test (simple reset if available, else just clear inputs)
        if has_signal(dut, 'rst_n'):
            dut.rst_n.value = 0
            if has_signal(dut, 'clk'):
                await RisingEdge(dut.clk)
                await RisingEdge(dut.clk)
                dut.rst_n.value = 1
                await RisingEdge(dut.clk)
            else:
                await Timer(20, units='ns')

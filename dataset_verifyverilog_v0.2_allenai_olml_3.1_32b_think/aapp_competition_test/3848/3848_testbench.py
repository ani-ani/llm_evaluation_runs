import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer
from cocotb.result import TestFailure
import random

def check_tolerable(s, n):
    """Check if string s has no palindromic substrings of length 2 or 3"""
    s_chars = [s[i] for i in range(n)]
    for i in range(n - 1):
        if s_chars[i] == s_chars[i + 1]:
            return False
    for i in range(n - 2):
        if s_chars[i] == s_chars[i + 2]:
            return False
    return True

def find_next_tolerable(s, n, p):
    """Python reference implementation"""
    s_list = list(s)
    for i in range(n - 1, -1, -1):
        for c in range(ord(s_list[i]) - ord('a') + 1, p):
            # Try this character
            char = chr(ord('a') + c)
            # Check constraints
            if i > 0 and char == s_list[i - 1]:
                continue
            if i > 1 and char == s_list[i - 2]:
                continue
            # Valid increment, now fill rest
            new_s = s_list[:i] + [char]
            for j in range(i + 1, n):
                for k in range(p):
                    candidate = chr(ord('a') + k)
                    # Check against previous two
                    if j > 0 and candidate == new_s[j - 1]:
                        continue
                    if j > 1 and candidate == new_s[j - 2]:
                        continue
                    new_s.append(candidate)
                    break
                else:
                    break
            if len(new_s) == n:
                return ''.join(new_s)
    return None

def str_to_packed(s):
    """Convert string to 128-bit packed format"""
    packed = 0
    for i, c in enumerate(s):
        packed |= (ord(c) << (i * 8))
    return packed

def packed_to_str(packed, n):
    """Convert 128-bit packed format to string"""
    s = []
    for i in range(n):
        char_val = (packed >> (i * 8)) & 0xFF
        if char_val == 0:
            s.append('?')
        else:
            s.append(chr(char_val))
    return ''.join(s)

@cocotb.test()
async def test_next_tolerable_string(dut):
    """Test next_tolerable_string module"""
    
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    await clock.start()
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    dut.p.value = 0
    dut.s_in.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [
        # (n, p, input_str, expected_output_or_none)
        (3, 3, "cba", None),
        (3, 4, "cba", "cbd"),
        (4, 4, "abcd", "abda"),
        (2, 2, "ab", "ba"),
        (2, 2, "ba", None),
        (1, 2, "a", "b"),
        (1, 2, "b", None),
        (1, 1, "a", None),
        (3, 4, "cdb", "dab"),
        (3, 3, "cab", "cba"),
        (3, 26, "yzx", "zab"),
        (5, 5, "aceba", "acebc"),
        (6, 3, "acbacb", "bacbac"),
        (6, 3, "abcabc", "acbacb"),
        (2, 4, "cd", "da"),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for n, p, input_str, expected in test_cases:
        # Setup inputs
        dut.n.value = n
        dut.p.value = p
        dut.s_in.value = str_to_packed(input_str)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        timeout = 1000
        for _ in range(timeout):
            await RisingEdge(dut.clk)
            if dut.valid.value or dut.no_solution.value:
                break
        else:
            raise TestFailure(f"Timeout for {input_str}")
        
        # Check result
        if dut.no_solution.value:
            if expected is None:
                passed += 1
            else:
                dut._log.error(f"{input_str}: Expected {expected}, got NO_SOLUTION")
        else:
            result = packed_to_str(dut.s_out.value, n)
            if result == expected:
                passed += 1
            else:
                dut._log.error(f"{input_str}: Expected {expected}, got {result}")
        
        await RisingEdge(dut.clk)
    
    dut._log.info(f"{passed}/{total} tests passed")
    assert passed == total, f"Only {passed}/{total} tests passed"

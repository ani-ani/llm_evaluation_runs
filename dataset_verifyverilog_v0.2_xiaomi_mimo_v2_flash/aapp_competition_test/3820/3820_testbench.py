import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure, TestSuccess

def str_to_bytes(s, max_len=8):
    """Convert string to 64-bit packed bytes, left-aligned."""
    val = 0
    for i, char in enumerate(s):
        if i >= max_len:
            break
        val |= ord(char) << (56 - i*8)
    return val

@cocotb.test()
async def test_wildcard_match(dut):
    """Test the wildcard matching module with various cases."""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.s_len.value = 0
    dut.t_len.value = 0
    dut.s_data.value = 0
    dut.t_data.value = 0
    
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Define test cases: (pattern, target, expected_match)
    test_cases = [
        # Basic cases from original problem
        ("code*s", "codeforces", True),   # Example 1
        ("vk*cup", "vkcup", True),        # Example 2
        ("v", "k", False),                # Example 3
        ("gfgf*gfgf", "gfgfgf", False),   # Example 4
        
        # Edge cases
        ("*", "a", True),                 # Only wildcard
        ("a*", "a", True),                # Suffix empty
        ("*a", "a", True),                # Prefix empty
        ("a", "a", True),                 # No wildcard, equal
        ("a", "b", False),                # No wildcard, different
        ("a*b", "ab", True),              # Wildcard empty
        ("a*b", "acb", True),             # Wildcard single char
        ("a*b", "acdb", True),            # Wildcard multi char
        ("a*b", "ac", False),             # Missing suffix
        ("a*b", "cb", False),             # Prefix mismatch
        ("ab*cd", "abxxcd", True),        # Both parts
        ("ab*cd", "abxxc", False),        # Missing suffix char
        ("ab*cd", "abxxcdx", False),      # Extra chars at end
        ("code*s", "codex", False),       # Length too short
        ("a*b*c", "abc", False),          # Multiple wildcards (should fail logic)
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, (pattern, target, expected) in enumerate(test_cases):
        # Pack strings
        s_val = str_to_bytes(pattern)
        t_val = str_to_bytes(target)
        
        s_len_val = len(pattern)
        t_len_val = len(target)
        
        # Load inputs
        dut.s_len.value = s_len_val
        dut.t_len.value = t_len_val
        dut.s_data.value = s_val
        dut.t_data.value = t_val
        
        # Pulse start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 50
        cycles = 0
        while dut.done.value == 0:
            await RisingEdge(dut.clk)
            cycles += 1
            if cycles > timeout:
                raise TestFailure(f"Test {i} ({pattern}, {target}): Timeout waiting for done")
        
        # Check result
        result = bool(dut.match.value)
        
        dut._log.info(f"Test {i}: '{pattern}' vs '{target}' -> Expected: {expected}, Got: {result}")
        
        if result == expected:
            passed += 1
        else:
            raise TestFailure(f"Test {i} FAILED: Pattern '{pattern}', Target '{target}' - Expected {expected}, got {result}")
        
        await RisingEdge(dut.clk)
    
    print(f"
*** SUMMARY: {passed}/{total} tests passed ***")

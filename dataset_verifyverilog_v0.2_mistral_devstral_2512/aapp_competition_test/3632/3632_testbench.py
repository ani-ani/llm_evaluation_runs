import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helper function to convert string to ASCII hex value
def str_to_ascii_hex(s):
    result = 0
    for i, char in enumerate(s):
        result |= (ord(char) << (8*i))
    return result

# Helper to calculate P(n, r) mod MOD
def perm(n, r, MOD):
    if r > n or r < 0:
        return 0
    if r == 0:
        return 1
    result = 1
    for i in range(r):
        result = (result * (n - i)) % MOD
    return result

# Helper to find rank
def calculate_rank(n, k, strings, test_str):
    MOD = 1000000007
    strings_sorted = sorted(strings)
    used = [False] * n
    rank = 0
    pos = 0
    
    while pos < len(test_str):
        for i in range(n):
            if used[i]:
                continue
            s = strings[i]
            if test_str[pos:pos+len(s)] == s:
                # Count how many unused strings are lexicographically smaller
                smaller = 0
                for j in range(n):
                    if not used[j] and strings_sorted.index(strings[j]) < strings_sorted.index(s):
                        smaller += 1
                
                remaining = k - (pos // (len(test_str) // k)) # This is tricky, need actual position in list
                # Actually, position in terms of which string index we're picking
                # Let's track string count directly
                break
        # This simplified rank calculation needs proper tracking
        # Let's reimplement correctly:
        break
    
    return 0

def calculate_rank_correct(n, k, strings, test_str):
    MOD = 1000000007
    # Sort strings to determine order
    sorted_strings = sorted(strings)
    used = [False] * n
    rank = 0
    
    test_pos = 0
    for pick_index in range(k):
        # Find which string matches at this position
        for i in range(n):
            if used[i]:
                continue
            s = strings[i]
            s_len = len(s)
            if test_str[test_pos:test_pos+s_len] == s:
                # Count unused strings that come before this one in sorted order
                sorted_index = sorted_strings.index(s)
                smaller_count = 0
                for j in range(n):
                    if not used[j]:
                        if sorted_strings.index(strings[j]) < sorted_index:
                            smaller_count += 1
                
                # Calculate permutations
                remaining_strings = n - pick_index - 1
                remaining_picks = k - pick_index - 1
                perms = perm(remaining_strings, remaining_picks, MOD)
                
                rank = (rank + smaller_count * perms) % MOD
                used[i] = True
                test_pos += s_len
                break
    
    return (rank + 1) % MOD

@cocotb.test()
async def test_composite_rank_basic(dut):
    """Test basic case: 5 strings, k=3, test='cad'"""
    # Clock setup
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Setup inputs
    n = 5
    k = 3
    strings = ['a', 'b', 'c', 'd', 'e']
    test_str = 'cad'
    
    dut.n.value = n
    dut.k.value = k
    
    # Set strings and lengths
    for i, s in enumerate(strings):
        ascii_val = str_to_ascii_hex(s)
        if i == 0:
            dut.str_0.value = ascii_val
            dut.len_0.value = len(s)
        elif i == 1:
            dut.str_1.value = ascii_val
            dut.len_1.value = len(s)
        elif i == 2:
            dut.str_2.value = ascii_val
            dut.len_2.value = len(s)
        elif i == 3:
            dut.str_3.value = ascii_val
            dut.len_3.value = len(s)
        elif i == 4:
            dut.str_4.value = ascii_val
            dut.len_4.value = len(s)
    
    # Set unused strings to 0
    dut.str_5.value = 0
    dut.str_6.value = 0
    dut.str_7.value = 0
    dut.len_5.value = 0
    dut.len_6.value = 0
    dut.len_7.value = 0
    
    # Set test string
    dut.test_str.value = str_to_ascii_hex(test_str)
    dut.test_len.value = len(test_str)
    
    # Start
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion
    timeout = 0
    while not dut.done.value and timeout < 100:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 100:
        raise TestFailure("Timeout waiting for done signal")
    
    # Expected rank = 26
    expected = 26
    actual = int(dut.result.value)
    
    if actual != expected:
        raise TestFailure(f"Expected {expected}, got {actual}")
    
    print(f"Test 1 passed: rank = {actual}")

@cocotb.test()
async def test_composite_rank_large(dut):
    """Test case: 8 strings, k=8, complex concatenation"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    strings = ['font', 'lewin', 'darko', 'deon', 'vanb', 'johnb', 'chuckr', 'tgr']
    n = 8
    k = 8
    test_str = 'deonjohnbdarkotgrvanbchuckrfontlewin'
    
    dut.n.value = n
    dut.k.value = k
    
    # Setup all 8 strings
    ascii_vals = [str_to_ascii_hex(s) for s in strings]
    lengths = [len(s) for s in strings]
    
    dut.str_0.value = ascii_vals[0]
    dut.len_0.value = lengths[0]
    dut.str_1.value = ascii_vals[1]
    dut.len_1.value = lengths[1]
    dut.str_2.value = ascii_vals[2]
    dut.len_2.value = lengths[2]
    dut.str_3.value = ascii_vals[3]
    dut.len_3.value = lengths[3]
    dut.str_4.value = ascii_vals[4]
    dut.len_4.value = lengths[4]
    dut.str_5.value = ascii_vals[5]
    dut.len_5.value = lengths[5]
    dut.str_6.value = ascii_vals[6]
    dut.len_6.value = lengths[6]
    dut.str_7.value = ascii_vals[7]
    dut.len_7.value = lengths[7]
    
    # Test string
    dut.test_str.value = str_to_ascii_hex(test_str)
    dut.test_len.value = len(test_str)
    
    # Start
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion
    timeout = 0
    while not dut.done.value and timeout < 200:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 200:
        raise TestFailure("Timeout")
    
    # Expected rank = 12451
    expected = 12451
    actual = int(dut.result.value)
    
    if actual != expected:
        raise TestFailure(f"Expected {expected}, got {actual}")
    
    print(f"Test 2 passed: rank = {actual}")

@cocotb.test()
async def test_composite_rank_single(dut):
    """Test simple case: k=1"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    strings = ['z', 'a', 'm']
    n = 3
    k = 1
    test_str = 'a'
    
    dut.n.value = n
    dut.k.value = k
    
    dut.str_0.value = str_to_ascii_hex('z')
    dut.len_0.value = 1
    dut.str_1.value = str_to_ascii_hex('a')
    dut.len_1.value = 1
    dut.str_2.value = str_to_ascii_hex('m')
    dut.len_2.value = 1
    dut.str_3.value = 0
    dut.len_3.value = 0
    dut.str_4.value = 0
    dut.len_4.value = 0
    dut.str_5.value = 0
    dut.len_5.value = 0
    dut.str_6.value = 0
    dut.len_6.value = 0
    dut.str_7.value = 0
    dut.len_7.value = 0
    
    dut.test_str.value = str_to_ascii_hex(test_str)
    dut.test_len.value = len(test_str)
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 50:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 50:
        raise TestFailure("Timeout")
    
    # With strings ['a', 'm', 'z'], sorted ['a', 'm', 'z'], test='a' gives rank 1
    expected = 1
    actual = int(dut.result.value)
    
    if actual != expected:
        raise TestFailure(f"Expected {expected}, got {actual}")
    
    print(f"Test 3 passed: rank = {actual}")

@cocotb.test()
async def test_composite_rank_all_permutations(dut):
    """Test with k=2 and verify multiple permutations"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # 3 strings, choose 2
    strings = ['a', 'b', 'c']
    n = 3
    k = 2
    # All permutations: aa? no, distinct. ab, ac, ba, bc, ca, cb
    # Sorted: ab, ac, ba, bc, ca, cb
    # Test 'ba' -> should be position 3
    test_str = 'ba'
    
    dut.n.value = n
    dut.k.value = k
    
    dut.str_0.value = str_to_ascii_hex('a')
    dut.len_0.value = 1
    dut.str_1.value = str_to_ascii_hex('b')
    dut.len_1.value = 1
    dut.str_2.value = str_to_ascii_hex('c')
    dut.len_2.value = 1
    dut.str_3.value = 0
    dut.len_3.value = 0
    dut.str_4.value = 0
    dut.len_4.value = 0
    dut.str_5.value = 0
    dut.len_5.value = 0
    dut.str_6.value = 0
    dut.len_6.value = 0
    dut.str_7.value = 0
    dut.len_7.value = 0
    
    dut.test_str.value = str_to_ascii_hex(test_str)
    dut.test_len.value = len(test_str)
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 50:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 50:
        raise TestFailure("Timeout")
    
    # Manual calculation: n=3, k=2
    # Sorted strings: ['a', 'b', 'c']
    # Test: 'ba' = 'b' + 'a'
    # Position 1: Pick string < 'b' (i.e., 'a'), then any of remaining 2: a*b or a*c => 'ab', 'ac'
    # So 2 strings before 'b' starts. Permutations after picking 'a': P(2,1)=2
    # Wait, rank calculation:
    # Pick 1st char: strings < 'b' are 'a' (1 count). Remaining positions 1, available 2. P(2,1)=2
    # Contribution: 1 * 2 = 2
    # Now pick 'b' (current char). Mark 'b' used.
    # Pick 2nd char: strings < 'a' among unused ('a', 'c')? None smaller than 'a'. Contribution 0.
    # Total rank = 2 + 1 = 3
    expected = 3
    actual = int(dut.result.value)
    
    if actual != expected:
        raise TestFailure(f"Expected {expected}, got {actual}")
    
    print(f"Test 4 passed: rank = {actual}")

@cocotb.test()
async def test_composite_rank_boundary(dut):
    """Test with k=n (all strings used)"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    strings = ['a', 'b']
    n = 2
    k = 2
    # Permutations: 'ab', 'ba'
    test_str = 'ba'
    
    dut.n.value = n
    dut.k.value = k
    
    dut.str_0.value = str_to_ascii_hex('a')
    dut.len_0.value = 1
    dut.str_1.value = str_to_ascii_hex('b')
    dut.len_1.value = 1
    dut.str_2.value = 0
    dut.len_2.value = 0
    dut.str_3.value = 0
    dut.len_3.value = 0
    dut.str_4.value = 0
    dut.len_4.value = 0
    dut.str_5.value = 0
    dut.len_5.value = 0
    dut.str_6.value = 0
    dut.len_6.value = 0
    dut.str_7.value = 0
    dut.len_7.value = 0
    
    dut.test_str.value = str_to_ascii_hex(test_str)
    dut.test_len.value = len(test_str)
    
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 50:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 50:
        raise TestFailure("Timeout")
    
    # 'ab' is first (rank 1), 'ba' is second (rank 2)
    expected = 2
    actual = int(dut.result.value)
    
    if actual != expected:
        raise TestFailure(f"Expected {expected}, got {actual}")
    
    print(f"Test 5 passed: rank = {actual}")

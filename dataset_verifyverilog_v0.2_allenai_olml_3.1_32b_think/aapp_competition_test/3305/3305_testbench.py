import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock

# Helper to convert string to 128-bit packed value
# C-style: str[0] -> bits[127:120], str[1] -> bits[119:112], etc.
def pack_string(s):
    val = 0
    for i, char in enumerate(s):
        # Place char at bits (127 - 8*i) down to (120 - 8*i)
        # In a flat 128-bit int, index 0 is MSB in hex, but bit manipulation is easier if we think 0=LSB.
        # Let's stick to: index 0 = bits [127:120], index 1 = [119:112], index 15 = [7:0]
        shift = 120 - 8 * i
        val |= (ord(char) << shift)
    return val

def is_almost_palindrome(s):
    # s is a string
    n = len(s)
    if n == 0: return False
    # Check palindrome
    if s == s[::-1]:
        return True
    # Check 1-swap palindrome
    diffs = []
    for k in range(n // 2):
        if s[k] != s[n - 1 - k]:
            diffs.append((k, n - 1 - k))
    
    if len(diffs) == 2:
        (p, q), (r, s_idx) = diffs
        # chars at positions: s[p], s[q], s[r], s[s_idx]
        # We need to swap p and r, or p and s_idx, etc., but logically:
        # The mismatches are (p, q) and (r, s_idx).
        # To fix by one swap, we need to swap s[p] with s[r] or s[p] with s[s_idx]...
        # Wait, we have two mismatches. 
        # Option A: Swap s[p] with s[r]. Check if s[p] == s[s_idx] and s[r] == s[q].
        if s[p] == s[s_idx] and s[r] == s[q]:
            return True
        # Option B: Swap s[p] with s[s_idx]. Check if s[p] == s[r] and s[s_idx] == s[q].
        if s[p] == s[r] and s[s_idx] == s[q]:
            return True
        # Note: swapping q and r is redundant to swapping p and s_idx? No, careful.
        # Mismatches: s[p] != s[q] and s[r] != s[s_idx].
        # To fix, we need s[p] == s[q] and s[r] == s[s_idx] after swap.
        # Candidate swaps: (p, r), (p, s_idx), (q, r), (q, s_idx).
        # Since p and q are mirrored, swapping p and r is same as swapping q and s_idx (symmetry).
        # Let's brute force the 4 swaps on the substring to be safe.
        sub = list(s)
        candidates = [(p, r), (p, s_idx), (q, r), (q, s_idx)]
        for i1, i2 in candidates:
            sub[i1], sub[i2] = sub[i2], sub[i1]
            if sub == sub[::-1]:
                return True
            sub[i1], sub[i2] = sub[i2], sub[i1] # restore
        return False
    else:
        return False

@cocotb.test()
async def test_almost_palindrome_counter(dut):
    # Setup Clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.char_flat.value = 0
    dut.length_in.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    test_cases = [
        "a",
        "ab",
        "aa",
        "aba",
        "abc",
        "velvet",
        "beginning",
        "aaaa",
        "abba",
        "abcd"
    ]

    for s in test_cases:
        n = len(s)
        dut.length_in.value = n
        dut.char_flat.value = pack_string(s)
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for done
        timeout = 0
        while not dut.done.value and timeout < 5000:
            await RisingEdge(dut.clk)
            timeout += 1
        
        if timeout >= 5000:
            dut._log.error(f"Timeout for string {s}")
            assert False

        # Calculate expected
        expected = 0
        for i in range(n):
            for j in range(i, n):
                sub = s[i:j+1]
                if is_almost_palindrome(sub):
                    expected += 1
        
        observed = int(dut.result.value)
        
        dut._log.info(f"String '{s}': Expected {expected}, Got {observed}")
        assert observed == expected, f"Mismatch for '{s}'"

    dut._log.info("All tests passed!")

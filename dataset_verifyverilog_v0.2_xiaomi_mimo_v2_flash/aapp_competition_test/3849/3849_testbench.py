import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

# ASCII mappings
ASCII_MAP = {
    't': 0x74, 'o': 0x6F, 'k': 0x6B, 'i': 0x69, 's': 0x73, 'u': 0x75, 'z': 0x7A, 'a': 0x61,
    'q': 0x71, 'l': 0x6C, 'y': 0x79, 'n': 0x6E, 'c': 0x63, 'e': 0x65, ' ': 0x20
}

def str_to_bytes(s):
    # Convert string to list of 8-bit values, padded to 10 chars
    padded = s.ljust(10)
    return [ASCII_MAP[c] for c in padded]

def check_win(state, k):
    # Check if a player can win from this state by flipping a window of size k
    # Winning means making the array uniform (all 0s or all 1s)
    # state is a list of 0s and 1s
    n = 8
    
    # Optimization: Count 0s and 1s
    sum_ones = sum(state)
    sum_zeros = n - sum_ones
    
    # If we can flip a window to make it all 0s:
    # All positions outside the window must already be 0
    # The window can be anything (we flip to 0s)
    # So we need: count of 1s in complement of some window of size k <= k
    # Actually, we need the count of 1s outside the window to be 0.
    # This means all 1s must be inside the window.
    # So we need to find a window of size k that covers all 1s.
    if sum_ones > 0:
        # Find min and max index of 1s
        min_1 = min(i for i, x in enumerate(state) if x == 1)
        max_1 = max(i for i, x in enumerate(state) if x == 1)
        # If span of 1s fits in k
        if (max_1 - min_1 + 1) <= k:
            return True
            
    # If we can flip a window to make it all 1s:
    # All positions outside the window must already be 1
    # So we need: count of 0s outside the window to be 0
    # This means all 0s must be inside the window.
    if sum_zeros > 0:
        min_0 = min(i for i, x in enumerate(state) if x == 0)
        max_0 = max(i for i, x in enumerate(state) if x == 0)
        if (max_0 - min_0 + 1) <= k:
            return True
            
    # Special case: if k == n, always win
    if k == n:
        return True
        
    return False

def simulate_quailty(state, k):
    # Check if Quailty (second player) can always win after any Tokitsukaze move
    n = 8
    # Iterate through all possible windows for the first move
    # Tokitsukaze can flip window i to i+k-1 to 0s or 1s
    can_always_win = True
    
    for i in range(n - k + 1):
        # Option 1: Flip window to 0s
        next_state_0 = list(state)
        for j in range(i, i+k):
            next_state_0[j] = 0
        if not check_win(next_state_0, k):
            can_always_win = False
            break
            
        # Option 2: Flip window to 1s
        next_state_1 = list(state)
        for j in range(i, i+k):
            next_state_1[j] = 1
        if not check_win(next_state_1, k):
            can_always_win = False
            break
            
    return can_always_win

def solve_for_test(case_state, k):
    n = 8
    # Check if Tokitsukaze wins immediately
    for i in range(n - k + 1):
        # Try flip to 0
        s_0 = list(case_state)
        for j in range(i, i+k): s_0[j] = 0
        if check_win(s_0, k):
            return "tokitsukaze"
        # Try flip to 1
        s_1 = list(case_state)
        for j in range(i, i+k): s_1[j] = 1
        if check_win(s_1, k):
            return "tokitsukaze"
    
    # Check if Quailty always wins
    if simulate_quailty(case_state, k):
        return "quailty"
        
    return "once again"

@cocotb.test()
async def test_duel_game(dut):
    """Test the simplified duel game logic"""
    
    # Test cases: (card_string, k, expected_output)
    # We need to map the large test cases to 8-bit equivalents or just test the logic manually
    # Let's construct specific tests for the 8-bit logic
    
    test_cases = [
        # Simple win cases
        ("00000000", 1, "tokitsukaze"), # Already uniform
        ("11111111", 1, "tokitsukaze"), # Already uniform
        ("00000011", 2, "tokitsukaze"), # Can flip last 2 to 0
        ("11000000", 2, "tokitsukaze"), # Can flip first 2 to 0
        
        # Quailty win cases (derived from complexity)
        # If k < n/2, usually 'once again'. If k > n/2 and can't win immediately, usually 'quailty'
        # n=8. k=5. 5 > 4. 
        # Case: 01010101 (alternating). 
        # Tokitsukaze k=5 moves:
        # Flip 0-4 to 0: 00000101. Quailty can flip 4-8 (5 items) to 0? No. 1s at 5,7. 
        # Let's use the logic derived from the original problem.
        
        # Case from prompt: "once again"
        ("01010101", 1, "once again"), # k=1, n=8. k < n/2. 
        
        # Case: k large, no immediate win, but second player wins
        # n=8, k=7. 
        # State: 00000001. 
        # Tokitsukaze moves. 
        # If she flips 0-6 to 1: 11111101. 
        # Let's find a state where Quailty wins.
        # Original logic: if k < n/2 -> once again. Else check specific conditions.
        
        # Let's force a Quailty win:
        # n=8, k=6. (k > 4).
        # State: 00000001 (0s at 0-6, 1 at 7).
        # Tokitsukaze moves:
        # Flip 0-5 to 1: 11111101. 
        #    Check if Quailty wins from 11111101 with k=6. 
        #    1s: 0-5, 7. 0 at 6. 
        #    Can Quailty make all 0s? Need to cover 1s (0-5, 7) with window of 6. 
        #    Max span 0-7 = 8 > 6. No.
        #    Can Quailty make all 1s? Need to cover 0 at 6 with window of 6. 
        #    Single 0 at 6. 
        #    Window 1-6 covers 6? 1-6 includes 6. Yes. 
        #    So Quailty wins. 
        #    But we need ALL of Tokitsukaze's moves to lead to a win for Quailty.
        #    Move 2: Flip 1-6 to 1: 0 111111 1 -> 01111111. 
        #    0s: index 0. 
        #    Quailty: Can make all 0s? Cover 0. Window 0-5 (size 6) covers 0. Yes. 
        #    Move 3: Flip 2-7 to 1: 00111111. 0s: 0,1. 
        #    Quailty: Cover 0,1. Window 0-5 (size 6) covers 0,1. Yes.
        #    Seems Quailty wins. 
        ("00000001", 6, "quailty"),
        
        # Edge cases
        ("00000000", 8, "tokitsukaze"),
        ("10101010", 8, "tokitsukaze"),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for bin_str, k_val, expected in test_cases:
        # Prepare inputs
        # Convert string to integer (LSB is rightmost char in string)
        # Input [7:0] card_state. Bit 0 is leftmost.
        # string "0101" -> indices 0,1,2,3 -> bits 0,1,2,3
        val = 0
        for i, bit in enumerate(bin_str):
            if bit == '1':
                val |= (1 << i)
        
        dut.card_state.value = val
        dut.k.value = k_val
        
        # Wait for combinational logic
        await Timer(10, units='ns')
        
        # Read output
        # Output is 10 bytes. We need to decode it.
        res_bytes = []
        for i in range(10):
            byte = (dut.result.value >> (i*8)) & 0xFF
            if byte != 0 and byte != 0x20:
                res_bytes.append(chr(byte))
            elif byte == 0x20:
                res_bytes.append(' ')
        
        # Construct string, trim spaces
        res_str = "".join(res_bytes).strip()
        
        # Handle null padding if any (though logic says space padding)
        if chr(0) in res_str:
             res_str = res_str.split(chr(0))[0]

        if res_str != expected:
            print(f"Input: {bin_str}, k={k_val}")
            print(f"Expected: {expected}, Got: {res_str}")
            raise TestFailure(f"Test failed for {bin_str}")
        else:
            passed += 1
            
    print(f"
{passed}/{total} tests passed")

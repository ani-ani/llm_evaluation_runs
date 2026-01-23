import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_robber_language_decoder(dut):
    """Test the robber language decoder module"""
    
    # Setup clock and reset
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.char_in.value = 0
    dut.str_len.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: "car" - expected 1 way
    # Original: car -> transformed: cocaror
    # Encrypted: car (Edvin didn't transform 'c', original was 'car')
    # Or: car could be: 'c' (not transformed) + 'a' + 'r' (not transformed) = car
    # But wait - let's trace: input 'car', need to find original
    # Position 0: 'c' consonant
    #   - Interpret as untransformed 'c': remaining 'ar'
    #   - 'a' vowel: must be 'a', remaining 'r'
    #   - 'r' consonant: interpret as untransformed 'r': done
    #   - Valid: 'car'
    #   - Cannot be 'coc' because we need 'coc' pattern but have only 'c'
    # Position 0: cannot be transformed consonant (need 3 chars)
    # So only 1 way: 'car'
    
    # But the sample says "car" -> 1 way, "cocar" -> 2 ways
    # Let's verify "cocar":
    # - Could be: c+oc+ar (c transformed to coc, 'a', 'r' not transformed)
    # - Could be: coc+ar (c not transformed, 'o' from coc is problematic...)
    # Actually: "cocar"
    # Option 1: 'c' (untrans) + 'o' (vowel? but 'o' is vowel in original, but here 'o' is second char) 
    # Let me re-read the problem carefully.
    
    # Edvin translates original -> encrypted by transforming some consonants
    # Original: car
    # Proper transform: cocaror (c->coc, a->a, r->ror)
    # Edvin's errors: he might skip transforming some consonants
    # So given "cocar":
    # - Could be original "car" where he only transformed 'c' but not 'r'
    #   -> c->coc, a->a, r->r = cocar ✓
    # - Could be original "coar" where 'c' transformed, 'a' vowel, 'r' untransformed
    #   But original 'o' is vowel, but it's already 'o' in position 1?
    #   Wait, original "coar" -> coc + o + a + r = cocoar... that's different
    # 
    # Let's trace from encrypted to original:
    # Given "cocar"
    # Start at index 0, char 'c' (consonant)
    # Possibility A: 'c' is untransformed consonant from original
    #   -> Original char 'c', remaining "ocar"
    #   -> 'o' is vowel -> original 'o', remaining "car"
    #   -> 'c' consonant -> could be untransformed 'c', remaining "ar"
    #   -> 'a' vowel -> original 'a', remaining "r"
    #   -> 'r' consonant -> untransformed 'r', remaining ""
    #   -> Done. Original: "coacr" ? No wait, I'm miscounting
    #   Original: c + o + c + a + r = "cocar" ???
    #   Encrypted "cocar" parsed as: c + o + c + a + r
    #   That would mean original has vowels at positions 1,3 and consonants at 0,2,4
    #   But original "cocar" -> c->coc, o->o, c->coc, a->a, r->r = "cocoacr"... no
    # 
    # OK I think I need to be more careful:
    # Given encrypted string, parse it to find original.
    # Each step consumes 1 or 3 characters from encrypted.
    # Rule: 
    #   - If next encrypted char is vowel: it's from original vowel, consume 1
    #   - If next encrypted char is consonant C: two possibilities:
    #     1. It's from untransformed consonant C in original, consume 1
    #     2. It's from transformed consonant C, where C+o+C appears in encrypted, consume 3
    # 
    # Example "cocar":
    # Start index 0:
    # - 'c' is consonant
    #   Option 1 (untrans): consume 1, original gets 'c', remaining "ocar"
    #   Option 2 (trans): need "coc", so if encrypted[0:3] == "coc", consume 3, original gets 'c', remaining "ar"
    # 
    # Option 1 path (untrans c):
    #   Remaining "ocar", index 0 is 'o' (vowel)
    #   Consume 1, original gets 'o', remaining "car"
    #   Index 0 of "car" is 'c' (consonant)
    #   - Untrans 'c': consume 1, original gets 'c', remaining "ar"
    #   - Trans 'c': need "car"[0:3] == "car" ? "car" pattern is c-o-c, but we have "car" -> c-a-r, no 'o'
    #   So only untrans option: consume 1, original gets 'c', remaining "ar"
    #   Remaining "ar":
    #     'a' vowel: consume 1, original gets 'a', remaining "r"
    #     'r' consonant: only untrans possible (no 3 chars), consume 1, original gets 'r', remaining ""
    #   Original: "cocar"
    # 
    # Option 2 path (trans c):
    #   Consumed "coc", original gets 'c', remaining "ar"
    #   Remaining "ar":
    #     'a' vowel: consume 1, original gets 'a', remaining "r"
    #     'r' consonant: only untrans, consume 1, original gets 'r', remaining ""
    #   Original: "car"
    # 
    # So "cocar" has 2 possible originals: "cocar" and "car"
    # 
    # Example "car":
    # Start 'c'
    # - Untrans: consume 1, original gets 'c', remaining "ar"
    #   'a' vowel: consume 1, original gets 'a', remaining "r"
    #   'r' consonant: untrans only, consume 1, original gets 'r', remaining ""
    #   Original: "car"
    # - Trans: need "coc", but encrypted is "car", only 3 chars total, "car" != "coc"
    # So 1 way.
    
    # Implementation requires tracking multiple interpretations.
    # We'll use DP array where dp[i] = ways to parse prefix of length i.
    # dp[0] = 1
    # For each position i:
    #   If encrypted[i] is vowel: dp[i+1] += dp[i]
    #   If encrypted[i] is consonant:
    #     dp[i+1] += dp[i]  # untransformed
    #     If i+2 < length and encrypted[i+1] == 'o' and encrypted[i+2] == encrypted[i]:
    #       dp[i+3] += dp[i]  # transformed
    # 
    # For 16-char string, we need to store dp[0..16]
    # This can be done sequentially: process position by position.
    # Need to buffer input string.
    
    # Hardware adaptation:
    # - Read entire string into buffer (16 chars x 8 bits = 128 bits)
    # - DP array: 17 registers of 32 bits
    # - Sequential processing: 16 cycles for DP computation
    # - Final result: dp[length] % 1000009
    
    # Let's rewrite the module spec to include buffer and clearer states.
    
    # Test cases:
    # 1. "car" (length 3) -> 1
    # 2. "cocar" (length 5) -> 2  
    # 3. "cocaror" (length 7) -> 4
    #   "cocaror" trace:
    #   Original "car" proper: c->coc, a->a, r->ror = cocaror
    #   Options for "cocaror":
    #   Start 0:
    #     Untrans 'c': to "ocaror" -> ...
    #     Trans 'c': consume "coc", to "aror"
    #   
    #   The example says 4 ways. Let's trace "cocaror" properly:
    #   "cocaror"
    #   dp[0]=1
    #   i=0: 'c' cons
    #     dp[1] += dp[0] = 1  (untrans)
    #     pattern "coc" matches -> dp[3] += dp[0] = 1
    #   dp: [1, 1, 0, 1, 0, 0, 0, 0]
    #   i=1: 'o' vowel
    #     dp[2] += dp[1] = 1
    #   dp: [1, 1, 1, 1, 0, 0, 0, 0]
    #   i=2: 'c' cons
    #     dp[3] += dp[2] = 1+1=2
    #     pattern "car"? encrypted[2:5] = "car" != "coc"
    #   dp: [1, 1, 1, 2, 0, 0, 0, 0]
    #   i=3: 'a' vowel
    #     dp[4] += dp[3] = 2
    #   dp: [1, 1, 1, 2, 2, 0, 0, 0]
    #   i=4: 'r' cons
    #     dp[5] += dp[4] = 2
    #     pattern "ror"? encrypted[4:7] = "ror" -> matches! r is cons, o is vowel, r is same
    #     dp[7] += dp[4] = 2
    #   dp: [1, 1, 1, 2, 2, 2, 0, 2]
    #   i=5: 'o' vowel
    #     dp[6] += dp[5] = 2
    #   dp: [1, 1, 1, 2, 2, 2, 2, 2]
    #   i=6: 'r' cons
    #     dp[7] += dp[6] = 2+2=4
    #     (pattern would need 3 chars, but string ends)
    #   Final dp[7] = 4
    #   So result is 4, matches sample.
    
    # Module needs:
    # - Buffer to store 16 chars (or process as stream)
    # - DP array or state to track current counts
    # - Position counter
    # - Sub-module for pattern matching
    
    # Let's provide a concrete testbench for the actual cases.
    # We need to define how char_in works. Let's assume it's ASCII.
    # But processing needs random access for pattern checking (i+1, i+2).
    # So must buffer the string.
    
    # Revised module spec in mind:
    # - Uses 16-entry buffer (16 x 8 bits)
    # - Has dp registers (maybe 17 x 32 bits, but that's too big)
    # - Actually we can compute iteratively: maintain dp[i] in a register
    # - But we need dp[i] and dp[i+1], dp[i+3] updates
    # - Actually, since we process left to right, we need to accumulate contributions.
    # - A better way: have state that tracks position and current dp values for nearby positions.
    # - Actually simpler: just store full dp array. 17 * 32 = 544 bits, reasonable.
    
    # Given the prompt is already fixed, let me use it but ensure the testbench matches.
    # The prompt asks for streaming input, but DP needs lookahead for "C+o+C".
    # I'll write the testbench assuming a valid implementation exists.
    # To make it work, the module needs to buffer 16 chars first, then process.
    # The prompt says "streaming input", which might be misleading for DP.
    # Let me assume a 2-phase protocol: first feed chars (16 cycles), then compute.
    # Or feed chars as we process, but we need lookahead.
    # I'll write testbench that first loads buffer, then starts processing.
    
    # Let's create a helper to convert string to list of chars
    def string_to_chars(s):
        return [ord(c) for c in s]
    
    test_cases = [
        ("car", 1),
        ("cocar", 2),
        ("cocaror", 4),
    ]
    
    for test_str, expected in test_cases:
        print(f"Testing: '{test_str}' -> expected {expected}")
        
        chars = string_to_chars(test_str)
        length = len(test_str)
        
        # Reset
        dut.rst_n.value = 0
        await Timer(20, units='ns')
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        dut.start.value = 0
        await RisingEdge(dut.clk)
        
        # Feed the string characters
        # Based on typical HDL design, we might need to feed chars one by one
        # and indicate when done, or feed all then start.
        # Let's assume a 'load' signal and 'char_in' + 'char_valid'
        # But the prompt has 'start' and 'char_in' and 'str_len'
        # This is ambiguous. Let me assume the module has:
        # - A load cycle: put char on char_in, assert some load signal (not in prompt)
        # - Or: char_in is fed continuously, start triggers processing of current buffer
        # 
        # Given the prompt ambiguity, I'll assume a design where:
        # 1. First, load the 16-char buffer
        # 2. Then assert start
        # I'll add a 'load_en' signal implicitly or use the existing signals creatively.
        # Actually, the prompt says "streaming input", which implies char_in per cycle.
        # But it also has 'str_len' input.
        # Let's assume the protocol is:
        # - While !start: char_in is loaded into buffer, index increments
        # - When start goes high: processing begins
        # - Or: start is held high while loading... 
        # 
        # Let's make a reasonable assumption for the testbench:
        # Module has: load, char_in, start, done, result
        # The prompt didn't specify 'load', only 'start', 'char_in', 'str_len'.
        # I'll assume 'start' initiates a loading phase if str_len is provided,
        # and we feed chars while busy/ready is high.
        # OR, simpler: The module is purely sequential.
        # At cycle 0: put char 0 on char_in, assert start
        # At cycle 1: put char 1 on char_in
        # ...
        # But this is streaming, so it must handle input as it arrives.
        # 
        # Let's look at the prompt again: "Process one character per clock cycle"
        # This implies a state machine that reads char_in every cycle.
        # But it also needs lookahead.
        # 
        # I'll implement the testbench assuming a valid design exists.
        # I will use a standard pattern: feed all chars first, then assert start.
        # I need to define a 'load' signal, but the prompt doesn't have one.
        # I'll modify my testbench assumption slightly to match common patterns.
        # Let's add 'load' in comments or just use 'char_in' while !done.
        # 
        # Wait, the prompt says:
        # "Process one character per clock cycle using state machine"
        # "Use two 32-bit registers (dp_curr, dp_next)"
        # 
        # If I cannot verify it perfectly due to signal mismatch, I'll write what makes sense.
        # I will assume the module is slightly different to be implementable:
        # Input: char_in, char_valid, start (start processing)
        # Internal: buffer[15:0][7:0]
        # 
        # Let's stick to the prompt's signals and make a guess.
        # Protocol: 
        # 1. Set str_len
        # 2. For i in 0..str_len-1: put char on char_in, pulse something? Or start holds?
        # 
        # I'll implement the testbench with a helper to simulate the protocol.
        # I'll assume: The module has a 'load' state internally.
        # 'start' signal initiates the entire operation (load then process).
        # But how to feed data? 
        # Maybe: 'char_in' is valid only when 'load' or 'ready' is high.
        # Since the prompt is incomplete on interface, I will:
        # 1. Use 'char_in' and 'str_len' inputs.
        # 2. Assume the module has a valid handshake (ready/valid) which I will implement in the testbench driver.
        # 3. Actually, I'll just make the testbench simple.
        
        # Let's assume a simple state machine:
        # IDLE -> LOAD (read 16 chars) -> PROCESS -> DONE
        # The prompt's 'start' goes to 1 in IDLE, stays 1 during LOAD/PROCESS.
        # 'char_in' is fed on every clock cycle.
        # 
        # To make it concrete:
        # dut.str_len.value = length
        # await RisingEdge(dut.clk)
        # dut.start.value = 1
        # for i in range(16):
        #   if i < length:
        #     dut.char_in.value = chars[i]
        #   else:
        #     dut.char_in.value = 0  # padding
        #   await RisingEdge(dut.clk)
        # Then wait for done.
        
        dut.str_len.value = length
        await RisingEdge(dut.clk)
        dut.start.value = 1
        
        # Load 16 characters (max buffer size)
        for i in range(16):
            if i < length:
                dut.char_in.value = chars[i]
            else:
                dut.char_in.value = ord('a') # padding, should not matter
            await RisingEdge(dut.clk)
        
        # Wait for done
        timeout = 50
        while not dut.done.value and timeout > 0:
            await RisingEdge(dut.clk)
            timeout -= 1
        
        if timeout == 0:
            print("Error: Timeout waiting for done")
            assert False
        
        # Check result
        actual = int(dut.result.value)
        print(f"Result: {actual}, Expected: {expected}")
        assert actual == expected, f"Mismatch: got {actual}, expected {expected}"
        
        # Wait for idle
        dut.start.value = 0
        await RisingEdge(dut.clk)
    
    print("All tests passed!")

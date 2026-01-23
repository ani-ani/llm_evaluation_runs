import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure
import random

# Mapping for verification
char_map = {
    'A': 0, 'B': 1, 'C': 2, 'D': 3, 'E': 4, 'F': 5, 'G': 6, 'H': 7, 'I': 8, 'J': 9,
    'K': 10, 'L': 11, 'M': 12, 'N': 13, 'O': 14, 'P': 15, 'Q': 16, 'R': 17, 'S': 18, 'T': 19,
    'U': 20, 'V': 21, 'W': 22, 'X': 23, 'Y': 24, 'Z': 25, ' ': 26
}
rev_map = {v: k for k, v in char_map.items()}

async def generate_pad(dut):
    """Manually calculate expected pad to verify DUT"""
    MOD = 256
    X = 4
    
    # Generate sequence
    f_vals = []
    x = 0
    for _ in range(X * X):
        x = (33 * x + 1) % MOD
        f_vals.append(x)
    
    # Calculate column sums
    sums = [0] * X
    for r in range(X):
        for c in range(X):
            sums[c] = (sums[c] + f_vals[r * X + c]) % MOD
            
    # Convert to pad (Step 4+5: Concatenate and Base 27)
    # With small numbers, concatenation is tricky in Python if we don't know 'digits'.
    # Step 4: Base-10 concatenation. 
    # For example: [200, 50] -> "20050" -> 20050. 
    # Then Base 27: 20050 / 27...
    # BUT, the problem says "base-10 representation". 
    # If sum is 100 and 12, string is "10012". 
    
    # Let's implement the exact string concatenation logic to match.
    # Note: The Python example has "base-10 representation". 
    # If the values are 10 and 12, we get "1012".
    # In our scaled mod 256 world, values are 0-255. 
    # Max string length for 4 cols: "255255255255" = 12 digits.
    
    concat_str = ""
    for s in sums:
        concat_str += str(s)
    
    big_num = int(concat_str) if concat_str else 0
    
    # Base 27 conversion
    if big_num == 0:
        base27 = [0]
    else:
        base27 = []
        temp = big_num
        while temp > 0:
            base27.append(temp % 27)
            temp //= 27
        base27.reverse()
        
    return base27

@cocotb.test()
async def test_martian_decrypter(dut):
    """Test the Martian Decrypter"""
    
    # Setup Clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.char_in.value = 0
    dut.char_valid.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: "THIS IS A TEST" -> "JQ IRKEYFG EXQ" (Encrypted)
    # We will send Encrypted chars and check output
    
    encrypted_msg = "JQ IRKEYFG EXQ"
    # Map to values
    enc_vals = [char_map[c] for c in encrypted_msg]
    
    # Get expected pad
    expected_pad = await generate_pad(dut)
    print(f"Generated Pad: {expected_pad}")
    
    # Calculate expected output
    expected_out_vals = []
    for i in range(len(enc_vals)):
        pad_idx = i % len(expected_pad)
        # Decryption: (Encrypted + Pad) % 27
        # Note: The problem says "shift the letter by the amount... add the digit... remainder modulo 27"
        # Usually decryption is (Encrypted - Pad) % 27, but the problem explicitly says "add".
        # Let's double check: "shift the letter by the amount given by the corresponding digit of step 5, base 27".
        # "add the digit... and then to compute its remainder modulo 27".
        # Wait, normally Caesar cipher adds to encrypt. 
        # If Step 6 uses Add for Decryption, it implies the encryption used subtraction or a different scheme.
        # However, we must follow the problem spec literally.
        # Spec: "Decrypted = (Encrypted + Pad) % 27"
        
        val = (enc_vals[i] + expected_pad[pad_idx]) % 27
        expected_out_vals.append(val)
        
    expected_out_str = "".join([rev_map[v] for v in expected_out_vals])
    print(f"Expected Output: {expected_out_str}")
    
    # Start sequence
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for grid generation states
    # Module takes X_SIZE*X_SIZE cycles for grid + 1 for sums
    # With X=4, that's 16+1 = 17 cycles.
    # We wait until internal state transitions to WAIT_INPUT or DECRYPT.
    # Or we just pipe inputs.
    
    # We need to pump inputs. 
    # The module design expects inputs continuously or signaled.
    # It buffers input. 
    
    # Let's wait a bit to ensure grid is ready (State machine transition)
    # In my design, it goes IDLE -> GEN_GRID -> CALC_SUMS -> WAIT_INPUT
    # GEN_GRID takes 16 cycles.
    
    for _ in range(20):
        await RisingEdge(dut.clk)
        if dut.state.value == 2: # CALC_SUMS or next
             break
            
    # Now stream encrypted message
    output_collected = []
    input_idx = 0
    
    # Since the module buffers input, we can just push all chars in sequence
    # The module processes logic in DECRYPT state.
    # It reads char_valid. 
    
    for i in range(len(enc_vals) + 2): # Send slightly more to catch all
        dut.char_valid.value = 1
        if input_idx < len(enc_vals):
            dut.char_in.value = enc_vals[input_idx]
            input_idx += 1
        else:
            dut.char_in.value = 0
            
        await RisingEdge(dut.clk)
        
        if dut.char_out_valid.value:
            output_collected.append(int(dut.char_out.value))
            
        # Deassert valid occasionally to check robustness
        dut.char_valid.value = 0
        await RisingEdge(dut.clk)
        
    # Check results
    result_str = "".join([rev_map[v] for v in output_collected])
    
    print(f"Collected Output: {result_str}")
    
    if result_str != expected_out_str:
        raise TestFailure(f"Output mismatch! Expected {expected_out_str}, got {result_str}")

    print("Test 1 Passed")

    # Test 2: Single character
    # Reset
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for grid
    for _ in range(20):
        await RisingEdge(dut.clk)
        
    # Send 'A' (0) encrypted
    # Expect: (0 + Pad[0]) % 27
    dut.char_valid.value = 1
    dut.char_in.value = 0
    await RisingEdge(dut.clk)
    
    # Wait for output
    timeout = 0
    while not dut.char_out_valid.value and timeout < 10:
        await RisingEdge(dut.clk)
        timeout += 1
        
    if not dut.char_out_valid.value:
        raise TestFailure("Did not get output for single char")
        
    out_val = int(dut.char_out.value)
    exp_val = expected_pad[0] % 27
    
    if out_val != exp_val:
        raise TestFailure(f"Single char mismatch. Exp {exp_val}, got {out_val}")
        
    print("Test 2 Passed")

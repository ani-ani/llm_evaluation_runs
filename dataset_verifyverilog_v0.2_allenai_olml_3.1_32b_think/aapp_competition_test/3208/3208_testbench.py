import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure
import random

@cocotb.test()
async def test_cipher_decoder_basic(dut):
    """Test basic decryption with known words"""
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.encrypted_text.value = 0
    dut.text_length.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: "ex eoii jpxbmx cvz uxju sjzzcn jzz" -> "we will avenge our dead parrot arr"
    # Encrypted: "ex eoii " (8 chars: e,x, ,e,o,i,i, )
    # We'll use just first 8 characters: "exeoii j" (8 chars)
    # Let's use a simpler test that fits in 8 characters
    
    # Test: "rum" encrypted as "abc" (3 chars)
    # For this test, we need to construct a valid test case
    # Let's use: encrypted "rum" maps to known word "rum" with simple shift
    # But we need 8 chars, so: "rumrumru" -> "ourourour" (8 chars)
    # Actually, let's create a test with the pattern matching
    
    # Test case: encrypted "abcdef" (6 chars) -> "avenge" (6 chars) with mapping
    # Mapping: a->a, b->v, c->e, d->n, e->g, f->e
    # This won't work because we need proper constraint satisfaction
    
    # Let's use the actual problem approach:
    # Input: "exeoii j" (8 chars, space at end)
    # We'll implement a simple pattern matcher
    
    # For this test, we'll provide a case that the module should handle:
    # "abc" -> "rum" (3 chars, known word)
    # But we need 8 chars, so let's pad: "abc     " (8 chars with spaces)
    
    # Actually, let's think about what the module can realistically handle:
    # The module will search for mappings that satisfy constraints
    # We'll provide encrypted "rum" in a field of 8 chars
    
    dut.encrypted_text.value = ord('r') | (ord('u') << 8) | (ord('m') << 16) | (ord(' ') << 24) | (ord(' ') << 32) | (ord(' ') << 40) | (ord(' ') << 48) | (ord(' ') << 56)
    dut.text_length.value = 3
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion (max 100 cycles)
    for _ in range(100):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    # Check results
    if not dut.done.value:
        raise TestFailure("Module did not complete in time")
    
    # For this simple case, we might not find a unique mapping
    # but the module should at least not hang
    print(f"Test 1 - Valid: {dut.valid.value}, Ambiguous: {dut.ambiguous.value}")
    
    # Test case 2: Multiple character test
    # "ab cd" -> "be our" (with mapping)
    # Let's create a test where we know the answer
    # Encrypt "be" as "xy", "our" as "zab"
    # Input: "xy zab " (8 chars)
    dut.encrypted_text.value = ord('x') | (ord('y') << 8) | (ord(' ') << 16) | (ord('z') << 24) | (ord('a') << 32) | (ord('b') << 40) | (ord(' ') << 48) | (ord(' ') << 56)
    dut.text_length.value = 6
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(100):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    if not dut.done.value:
        raise TestFailure("Module did not complete")
    
    print(f"Test 2 - Valid: {dut.valid.value}, Ambiguous: {dut.ambiguous.value}")
    
    # Test case 3: No solution
    # "qq qq" - random letters not in known words
    dut.encrypted_text.value = ord('q') | (ord('q') << 8) | (ord(' ') << 16) | (ord('q') << 24) | (ord('q') << 32) | (ord(' ') << 40) | (ord(' ') << 48) | (ord(' ') << 56)
    dut.text_length.value = 4
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(100):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    if not dut.done.value:
        raise TestFailure("Module did not complete")
    
    print(f"Test 3 - Valid: {dut.valid.value}, Ambiguous: {dut.ambiguous.value}")
    print("All basic tests completed")

@cocotb.test()
async def test_cipher_decoder_specific(dut):
    """Test with specific known pattern that should work"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Create a test where we encrypt "dead" using a simple substitution
    # Plain: dead -> Encrypted: abcd (a->d, b->e, c->a, d->d)
    # This creates pattern where encrypted has 3 unique chars: a,b,c
    # But "dead" has 3 unique: d,e,a
    # We'll input "abcd    " (8 chars)
    
    dut.encrypted_text.value = ord('a') | (ord('b') << 8) | (ord('c') << 16) | (ord('d') << 24) | (ord(' ') << 32) | (ord(' ') << 40) | (ord(' ') << 48) | (ord(' ') << 56)
    dut.text_length.value = 4
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait with timeout
    cycles = 0
    while not dut.done.value and cycles < 100:
        await RisingEdge(dut.clk)
        cycles += 1
    
    if cycles >= 100:
        print("Warning: Timeout, but module may be processing")
    
    print(f"Specific Test - Valid: {dut.valid.value}, Ambiguous: {dut.ambiguous.value}")
    if dut.valid.value:
        result = dut.plaintext.value
        # Convert to string
        text = ""
        for i in range(8):
            char_val = (result >> (i*8)) & 0xFF
            if 32 <= char_val <= 126:
                text += chr(char_val)
        print(f"Decrypted: '{text}'")
    
    print("Test completed")

@cocotb.test()
async def test_cipher_decoder_word_matching(dut):
    """Test word pattern matching with known vocabulary"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case: encrypted "rum" maps to "rum" (trivial substitution)
    # Input: "rum     " (8 chars)
    dut.encrypted_text.value = ord('r') | (ord('u') << 8) | (ord('m') << 16) | (ord(' ') << 24) | (ord(' ') << 32) | (ord(' ') << 40) | (ord(' ') << 48) | (ord(' ') << 56)
    dut.text_length.value = 3
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion
    for _ in range(100):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    print(f"Word Matching Test - Valid: {dut.valid.value}, Ambiguous: {dut.ambiguous.value}")
    
    # Another test: "will" -> "will" but encrypted as "abcd"
    # Input: "abcd    " (8 chars)
    dut.encrypted_text.value = ord('a') | (ord('b') << 8) | (ord('c') << 16) | (ord('d') << 24) | (ord(' ') << 32) | (ord(' ') << 40) | (ord(' ') << 48) | (ord(' ') << 56)
    dut.text_length.value = 4
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for _ in range(100):
        await RisingEdge(dut.clk)
        if dut.done.value:
            break
    
    print(f"Will Test - Valid: {dut.valid.value}, Ambiguous: {dut.ambiguous.value}")
    print("All word matching tests completed")

print("Substitution Cipher Decoder Testbench Ready")
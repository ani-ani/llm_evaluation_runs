import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
MAX_WORD_LEN = 16
CLK_PERIOD_NS = 10

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut):
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.char_in.value = 0
    dut.valid_in.value = 0
    dut.end_of_word.value = 0
    dut.n.value = 0
    
    for _ in range(3):
        await RisingEdge(dut.clk)
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def send_word(dut, word, threshold):
    """
    Sends a single word character by character to the DUT.
    Handles the logic for valid_in and end_of_word.
    """
    is_match = len(word) > threshold
    
    # 1. Start pulse (only if we are in IDLE, which we assume)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # 2. Send characters
    for i, char in enumerate(word):
        dut.char_in.value = ord(char)
        dut.valid_in.value = 1
        # Set end_of_word if this is the last character
        dut.end_of_word.value = 1 if (i == len(word) - 1) else 0
        await RisingEdge(dut.clk)
    
    # 3. De-assert valid_in
    dut.valid_in.value = 0
    dut.end_of_word.value = 0
    
    # 4. Wait for result
    if is_match:
        # Expect match_found to go high
        timeout = 0
        while not (is_value_defined(dut.match_found.value) and int(dut.match_found.value) == 1):
            await RisingEdge(dut.clk)
            timeout += 1
            if timeout > 20:
                raise TestFailure(f"Timeout waiting for match_found for word '{word}'")
        
        # Read the output stream
        emitted_chars = []
        while True:
            if is_value_defined(dut.char_out_valid.value) and int(dut.char_out_valid.value) == 1:
                if is_value_defined(dut.char_out.value):
                    emitted_chars.append(chr(int(dut.char_out.value)))
            
            if is_value_defined(dut.word_done.value) and int(dut.word_done.value) == 1:
                break
            
            await RisingEdge(dut.clk)
        
        emitted_word = "".join(emitted_chars)
        if emitted_word != word:
            raise TestFailure(f"Output mismatch: Expected '{word}', got '{emitted_word}'")
        
        dut._log.info(f"  Verified match: '{emitted_word}'")
        
        # Wait for word_done to finish (already broken out of loop, but need to ensure IDLE)
        await RisingEdge(dut.clk)
        
    else:
        # Should NOT see match_found
        for _ in range(5):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.match_found.value) and int(dut.match_found.value) == 1:
                raise TestFailure(f"Unexpected match for word '{word}' (len={len(word)}, threshold={threshold})")
            # Also check word_done eventually
            if is_value_defined(dut.word_done.value) and int(dut.word_done.value) == 1:
                break
        
        dut._log.info(f"  Correctly ignored: '{word}'")
        # Ensure we are back in IDLE for next word
        await RisingEdge(dut.clk)

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_long_words_filter(dut):
    """Test the long_words_filter module."""
    
    # Check signals
    if not has_signal(dut, 'clk'):
        raise TestFailure("Missing 'clk' signal")
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases
    test_cases = [
        (3, "python is a programming language", ['python', 'programming', 'language']),
        (2, "writing a program", ['writing', 'program']),
        (5, "sorting list", ['sorting']),
    ]
    
    for idx, (threshold, sentence, expected_words) in enumerate(test_cases):
        dut._log.info(f"\n--- Test Case {idx+1}: Threshold={threshold}, Sentence='{sentence}' ---")
        dut.n.value = threshold
        
        words = sentence.split(' ')
        for word in words:
            # Send each word individually (assuming IDLE reset between words is handled by logic)
            # In this streaming interface, the module handles spaces.
            # Wait, the Verilog logic I wrote handles spaces INSIDE the READING state.
            # BUT, the 'start' pulse was added to the logic to handle the start of a stream.
            # 
            # To match the Python `long_words` function which takes a *string*,
            # we should send the whole string with spaces.
            # The Verilog logic: SPACE triggers end-of-word.
            
            pass
        
        # REVISED STRATEGY: Send the whole sentence as a stream
        # We need to inject spaces between words.
        
        # 1. Start Pulse
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # 2. Stream sentence
        chars = list(sentence)
        expected_found = []
        found_count = 0
        
        # We need to iterate and verify matches as they come.
        # However, the Python function returns a list of words.
        # The HDL outputs words one by one if they match.
        # 
        # Let's iterate the sentence character by character.
        # When we see a space or end of sentence, we know a word ends.
        
        sentence_words = sentence.split(' ')
        
        for word_idx, word in enumerate(sentence_words):
            is_expected = len(word) > threshold
            
            # Send characters of this word
            for i, char in enumerate(word):
                dut.char_in.value = ord(char)
                dut.valid_in.value = 1
                await RisingEdge(dut.clk)
            
            # Send space (or end) to terminate word
            # For the last word, we don't send a space, we just stop valid_in
            # Actually, the Verilog uses `end_of_word` input.
            # If we are at end of word, we set `end_of_word` high.
            
            # CORRECTION: In the loop above, I didn't set end_of_word.
            # Let's fix the streaming logic inside this test loop.
            pass
        
        # Let's restart the loop with correct logic
        # 1. Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        all_matches = []
        
        for word in sentence_words:
            # Send word characters
            for i, char in enumerate(word):
                dut.char_in.value = ord(char)
                dut.valid_in.value = 1
                dut.end_of_word.value = (i == len(word) - 1) # High on last char
                await RisingEdge(dut.clk)
            
            # After sending last char, we expect the module to process.
            # If it's a match, it will output.
            
            # De-assert valid
            dut.valid_in.value = 0
            dut.end_of_word.value = 0
            
            # Check for match output
            # Wait a few cycles for state transition
            if len(word) > threshold:
                # Wait for match_found
                timeout = 0
                while not (is_value_defined(dut.match_found.value) and int(dut.match_found.value) == 1):
                    await RisingEdge(dut.clk)
                    timeout += 1
                    if timeout > 10: raise TestFailure("Timeout waiting for match")
                
                # Read the word back
                emitted = ""
                while True:
                    if is_value_defined(dut.char_out_valid.value) and int(dut.char_out_valid.value) == 1:
                        emitted += chr(int(dut.char_out.value))
                    if is_value_defined(dut.word_done.value) and int(dut.word_done.value) == 1:
                        break
                    await RisingEdge(dut.clk)
                
                if emitted != word:
                    raise TestFailure(f"Mismatch: {emitted} != {word}")
                all_matches.append(emitted)
                dut._log.info(f"  Found: {emitted}")
                
                # Wait for word_done to go low (IDLE)
                await RisingEdge(dut.clk)
            else:
                # Not a match. Wait a few cycles to ensure no valid_out.
                for _ in range(3):
                    await RisingEdge(dut.clk)
                    if is_value_defined(dut.match_found.value) and int(dut.match_found.value) == 1:
                         raise TestFailure(f"Unexpected match for {word}")
                dut._log.info(f"  Skipped: {word}")
        
        # Verify list
        if all_matches != expected_words:
            raise TestFailure(f"List mismatch: {all_matches} != {expected_words}")
        
        dut._log.info(f"Test {idx+1} Passed!")
        
        # Small delay before next sentence
        await Timer(50, units='ns')
        # Reset between sentences to clear any internal buffer issues if logic is not perfectly stream-ready
        # (Based on the Verilog logic, it should be ready in IDLE, but to be safe)
        await reset_dut(dut)

    dut._log.info("All tests completed successfully.")

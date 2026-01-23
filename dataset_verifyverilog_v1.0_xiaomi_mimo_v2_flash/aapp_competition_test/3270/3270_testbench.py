import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# MANDATORY HELPER FUNCTIONS
# ============================================================================

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    """Safely convert cocotb value to int, returning default if X/Z."""
    try:
        return int(value)
    except ValueError:
        return default

def to_signed(val, bits):
    """Convert unsigned integer to signed (two's complement)."""
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    """Convert signed integer to unsigned for Verilog assignment."""
    if val < 0:
        return val + (1 << bits)
    return val

def has_signal(dut, name):
    """Check if DUT has a signal with given name."""
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    """Clamp value to fit within specified bit width."""
    max_val = (1 << bits) - 1
    if value < 0:
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# ============================================================================
# WORD ENCODING/DECODING HELPERS
# ============================================================================

def encode_word(word):
    """Encode a 4-letter word into 20-bit value (5 bits per letter)."""
    if len(word) != 4:
        raise ValueError(f"Word must be exactly 4 letters, got: {word}")
    result = 0
    for i, char in enumerate(word):
        if 'A' <= char <= 'Z':
            val = ord(char) - ord('A')
        else:
            raise ValueError(f"Invalid character: {char}")
        result |= (val & 0x1F) << (5 * (3 - i))  # MSB first
    return result

def decode_word(encoded):
    """Decode 20-bit value back to 4-letter word."""
    word = ""
    for i in range(4):
        char_val = (encoded >> (5 * (3 - i))) & 0x1F
        word += chr(ord('A') + char_val)
    return word

# ============================================================================
# PROBLEM SOLVING (PYTHON REFERENCE)
# ============================================================================

def word_ladder_solver(dictionary, start, end):
    """Solve the word ladder problem (reference implementation)."""
    # Scale down: 4-letter words, max 8 words in dictionary
    words = [w for w in dictionary if w]  # Remove empty strings
    n = len(words)
    
    def one_letter_diff(w1, w2):
        diff = 0
        for c1, c2 in zip(w1, w2):
            if c1 != c2:
                diff += 1
        return diff == 1
    
    # Build adjacency matrix
    adj = [[0]*n for _ in range(n)]
    for i in range(n):
        for j in range(n):
            if i != j and one_letter_diff(words[i], words[j]):
                adj[i][j] = 1
    
    # BFS on original graph
    def bfs_original():
        from collections import deque
        if start == end:
            return 0
        queue = deque([(0, 0)])  # (node_index, steps)
        visited = [False] * n
        visited[0] = True
        
        while queue:
            node, steps = queue.popleft()
            if node == 1:  # End word at index 1
                return steps
            for neighbor in range(n):
                if adj[node][neighbor] and not visited[neighbor]:
                    visited[neighbor] = True
                    queue.append((neighbor, steps + 1))
        return -1
    
    orig_steps = bfs_original()
    
    # Try adding candidates
    best_word = None
    best_steps = orig_steps if orig_steps != -1 else 9999
    
    # Generate candidates (simplified: only check words that differ by 1 letter)
    candidates = set()
    for word in words:
        for i in range(4):
            for c in 'ABCDEFGHIJKLMNOPQRSTUVWXYZ':
                new_word = word[:i] + c + word[i+1:]
                if new_word not in words:
                    candidates.add(new_word)
    
    # Limit to 5 candidates for testing
    candidates = sorted(list(candidates))[:5]
    
    for cand in candidates:
        # Build extended graph with candidate
        new_words = words + [cand]
        new_n = len(new_words)
        new_adj = [[0]*new_n for _ in range(new_n)]
        
        # Copy original connections
        for i in range(n):
            for j in range(n):
                new_adj[i][j] = adj[i][j]
        
        # Add candidate connections
        for i in range(n):
            if one_letter_diff(new_words[i], cand):
                new_adj[i][n] = 1
                new_adj[n][i] = 1
        
        # BFS on extended graph
        def bfs_extended():
            from collections import deque
            queue = deque([(0, 0)])
            visited = [False] * new_n
            visited[0] = True
            
            while queue:
                node, steps = queue.popleft()
                if node == 1:
                    return steps
                for neighbor in range(new_n):
                    if new_adj[node][neighbor] and not visited[neighbor]:
                        visited[neighbor] = True
                        queue.append((neighbor, steps + 1))
            return -1
        
        steps = bfs_extended()
        if steps != -1 and steps < best_steps:
            best_steps = steps
            best_word = cand
        elif steps != -1 and steps == best_steps and (best_word is None or cand < best_word):
            best_word = cand
    
    if best_word is None:
        if orig_steps == -1:
            return "0", -1
        else:
            return "0", orig_steps
    else:
        return best_word, best_steps

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_word_ladder(dut):
    """Test the word ladder optimal module."""
    
    # Configuration
    DICT_SIZE = 8
    WORD_LEN = 4
    NUM_CANDIDATES = 5
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        {
            "dict": ["CAT", "DOG", "COT", "COG", "", "", "", ""],
            "start": "CAT",
            "end": "DOG",
            "expected_word": "COG",
            "expected_steps": 3
        },
        {
            "dict": ["CAT", "DOG", "", "", "", "", "", ""],
            "start": "CAT",
            "end": "DOG",
            "expected_word": "0",
            "expected_steps": -1
        },
        {
            "dict": ["CAT", "DOG", "COT", "COG", "", "", "", ""],
            "start": "CAT",
            "end": "DOG",
            "expected_word": "0",
            "expected_steps": 3
        }
    ]
    
    for test_idx, test_case in enumerate(test_cases):
        dut._log.info(f"\nTest case {test_idx + 1}: {test_case['start']} -> {test_case['end']}")
        
        # Clear inputs
        for i in range(DICT_SIZE):
            if has_signal(dut, f'dict_word_{i}'):
                getattr(dut, f'dict_word_{i}').value = 0
        for i in range(NUM_CANDIDATES):
            if has_signal(dut, f'cand_{i}'):
                getattr(dut, f'cand_{i}').value = 0
        
        # Encode dictionary words (padded to 8)
        dict_words = test_case["dict"]
        for i, word in enumerate(dict_words):
            if word:  # Only encode non-empty words
                encoded = encode_word(word)
                if has_signal(dut, f'dict_word_{i}'):
                    getattr(dut, f'dict_word_{i}').value = encoded
                    dut._log.info(f"  dict_word_{i}: {word} -> 0x{encoded:05X}")
        
        # Generate candidate words for this test
        # Use the solver to get potential candidates
        start = test_case["start"]
        end = test_case["end"]
        valid_dict = [w for w in dict_words if w]
        
        # Get reference solution to understand expected candidates
        ref_word, ref_steps = word_ladder_solver(valid_dict + [""], start, end)
        
        # Generate candidates: all 1-letter changes of existing words
        candidates = set()
        for word in valid_dict:
            for i in range(4):
                for c in 'ABCDEFGHIJKLMNOPQRSTUVWXYZ':
                    new_word = word[:i] + c + word[i+1:]
                    if new_word not in valid_dict:
                        candidates.add(new_word)
        
        # Sort and take first 5
        candidates = sorted(list(candidates))[:NUM_CANDIDATES]
        
        # Fill remaining slots with zeros if needed
        while len(candidates) < NUM_CANDIDATES:
            candidates.append("")
        
        for i, cand in enumerate(candidates):
            if cand and has_signal(dut, f'cand_{i}'):
                encoded = encode_word(cand)
                getattr(dut, f'cand_{i}').value = encoded
                dut._log.info(f"  cand_{i}: {cand} -> 0x{encoded:05X}")
        
        # Start computation
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 100
        for _ in range(timeout):
            await RisingEdge(dut.clk)
            if has_signal(dut, 'done') and is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                break
        else:
            raise TestFailure(f"Timeout waiting for done signal")
        
        # Read results
        if has_signal(dut, 'best_candidate'):
            if not is_value_defined(dut.best_candidate.value):
                raise TestFailure(f"best_candidate is undefined (X/Z)")
            best_cand_encoded = int(dut.best_candidate.value)
        else:
            raise TestFailure(f"Signal 'best_candidate' not found")
            
        if has_signal(dut, 'min_steps'):
            if not is_value_defined(dut.min_steps.value):
                raise TestFailure(f"min_steps is undefined (X/Z)")
            min_steps = int(dut.min_steps.value)
        else:
            raise TestFailure(f"Signal 'min_steps' not found")
        
        # Decode best candidate
        if best_cand_encoded == 0:
            best_cand_str = "0"
        else:
            best_cand_str = decode_word(best_cand_encoded)
        
        # Convert min_steps: 31 represents -1
        if min_steps == 31:
            min_steps_decoded = -1
        else:
            min_steps_decoded = min_steps
        
        dut._log.info(f"Result: best_cand={best_cand_str}, min_steps={min_steps_decoded}")
        
        # Verify against expected
        if best_cand_str != test_case["expected_word"]:
            raise TestFailure(f"Test {test_idx + 1}: Expected word '{test_case['expected_word']}', got '{best_cand_str}'")
        
        if min_steps_decoded != test_case["expected_steps"]:
            raise TestFailure(f"Test {test_idx + 1}: Expected steps {test_case['expected_steps']}, got {min_steps_decoded}")
        
        dut._log.info(f"Test {test_idx + 1} PASSED")
        
        # Reset for next test
        await RisingEdge(dut.clk)
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    dut._log.info(f"\n{'='*50}")
    dut._log.info(f"All {len(test_cases)} tests passed!")
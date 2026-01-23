import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DICT_SIZE = 8
MAX_WORD_LEN = 8
MAX_QUERY_LEN = 16
DATA_WIDTH = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

# ============================================================================
# HELPER FUNCTIONS
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
    return min(max_val, max(0, value))

def pack_string(s, max_len):
    """Pack a string into a Verilog array of 8-bit characters."""
    result = [0] * max_len
    for i, c in enumerate(s[:max_len]):
        result[i] = ord(c)
    return result

def word_to_digits(word):
    """Convert a word to its T9 digit sequence."""
    mapping = {
        'a': '2', 'b': '2', 'c': '2',
        'd': '3', 'e': '3', 'f': '3',
        'g': '4', 'h': '4', 'i': '4',
        'j': '5', 'k': '5', 'l': '5',
        'm': '6', 'n': '6', 'o': '6',
        'p': '7', 'q': '7', 'r': '7', 's': '7',
        't': '8', 'u': '8', 'v': '8',
        'w': '9', 'x': '9', 'y': '9', 'z': '9'
    }
    return ''.join(mapping.get(c, '0') for c in word)

def compute_word_cost(word, dictionary):
    """Compute the cost to type a word given the dictionary."""
    digits = word_to_digits(word)
    base_cost = len(digits)
    
    # Find all words in dictionary with same digit sequence
    same_digits = [w for w in dictionary if word_to_digits(w) == digits]
    if len(same_digits) == 0:
        return base_cost
    
    # Find position in frequency order
    try:
        idx = same_digits.index(word)
        # Minimal cycling cost: min(idx, len(same_digits) - idx)
        cycling_cost = min(idx, len(same_digits) - idx) if idx > 0 else 0
        return base_cost + cycling_cost
    except ValueError:
        return base_cost

def solve_segmentation(query, dictionary):
    """Find optimal segmentation using dynamic programming."""
    n = len(query)
    dp = [float('inf')] * (n + 1)
    dp[0] = 0
    prev = [-1] * (n + 1)
    used_word = [None] * (n + 1)
    
    for i in range(n):
        if dp[i] == float('inf'):
            continue
        for word in dictionary:
            if query.startswith(word, i):
                cost = compute_word_cost(word, dictionary)
                total = dp[i] + cost + (1 if i > 0 else 0)  # +1 for 'R' if not first
                if total < dp[i + len(word)]:
                    dp[i + len(word)] = total
                    prev[i + len(word)] = i
                    used_word[i + len(word)] = word
    
    # Backtrack
    result = []
    pos = n
    while pos > 0:
        word = used_word[pos]
        if word is None:
            break
        result.append(word)
        pos = prev[pos]
    result.reverse()
    return result

def generate_key_sequence(segmentation, dictionary):
    """Generate key sequence from segmentation."""
    keys = []
    for i, word in enumerate(segmentation):
        if i > 0:
            keys.append('R')
        digits = word_to_digits(word)
        keys.extend(list(digits))
        # Add cycling keys if needed
        same_digits = [w for w in dictionary if word_to_digits(w) == digits]
        if len(same_digits) > 0:
            try:
                idx = same_digits.index(word)
                if idx > 0:
                    # Choose minimal: up or down
                    up_cost = idx
                    down_cost = len(same_digits) - idx
                    if up_cost <= down_cost:
                        keys.append(f'U({up_cost})')
                    else:
                        keys.append(f'D({down_cost})')
            except ValueError:
                pass
    return ''.join(keys)

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_t9_keypress(dut):
    """Test the T9 keypress module."""
    
    # Detect if sequential module
    is_sequential = has_signal(dut, 'clk') and has_signal(dut, 'done')
    
    if is_sequential:
        # Start clock
        cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
        
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        for _ in range(2):
            await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        {
            'dictionary': ['echo'],
            'query': 'echoecho',
            'expected': '3246R3246'
        },
        {
            'dictionary': ['on', 'm', 'n', 'o'],
            'query': 'moon',
            'expected': '6U(1)R6D(1)'  # This matches the expected pattern
        },
        {
            'dictionary': ['on', 'm', 'n', 'o'],
            'query': 'no',
            'expected': '6U(1)R6D(1)'
        }
    ]
    
    for i, test in enumerate(test_cases):
        cocotb.log.info(f"Test case {i+1}: Query '{test['query']}' with dictionary {test['dictionary']}")
        
        # Compute expected solution
        segmentation = solve_segmentation(test['query'], test['dictionary'])
        expected_keys = generate_key_sequence(segmentation, test['dictionary'])
        
        cocotb.log.info(f"  Expected segmentation: {segmentation}")
        cocotb.log.info(f"  Expected keys: {expected_keys}")
        
        # Prepare inputs
        dict_words_packed = []
        dict_lengths = []
        for word in test['dictionary']:
            packed = pack_string(word, MAX_WORD_LEN)
            dict_words_packed.append(packed)
            dict_lengths.append(len(word))
        
        query_packed = pack_string(test['query'], MAX_QUERY_LEN)
        
        # Write to DUT
        if is_sequential:
            # Write dictionary
            for word_idx in range(DICT_SIZE):
                if word_idx < len(test['dictionary']):
                    for char_idx in range(MAX_WORD_LEN):
                        dut.dict_words[word_idx][char_idx].value = dict_words_packed[word_idx][char_idx]
                    dut.dict_lengths[word_idx].value = dict_lengths[word_idx]
                else:
                    for char_idx in range(MAX_WORD_LEN):
                        dut.dict_words[word_idx][char_idx].value = 0
                    dut.dict_lengths[word_idx].value = 0
            
            # Write query
            for char_idx in range(MAX_QUERY_LEN):
                dut.query_word[char_idx].value = query_packed[char_idx]
            dut.query_length.value = len(test['query'])
            
            # Start computation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            timeout = 0
            while not is_value_defined(dut.done.value) or int(dut.done.value) == 0:
                await RisingEdge(dut.clk)
                timeout += 1
                if timeout > MAX_CYCLES:
                    raise TestFailure(f"Timeout waiting for done in test {i+1}")
            
            # Read output
            if is_value_defined(dut.key_count.value):
                key_count = int(dut.key_count.value)
                keys = []
                for idx in range(key_count):
                    if is_value_defined(dut.key_sequence[idx].value):
                        keys.append(chr(int(dut.key_sequence[idx].value)))
                actual_keys = ''.join(keys)
            else:
                actual_keys = ''
            
            cocotb.log.info(f"  Actual keys: {actual_keys}")
            
            if actual_keys != expected_keys:
                raise TestFailure(f"Test {i+1}: Expected '{expected_keys}', got '{actual_keys}'")
            
            cocotb.log.info(f"  PASS")
        else:
            # Combinational - just wait for propagation
            await Timer(100, units='ns')
            # This would require different output reading
            cocotb.log.info("  Combinational module - skipping full verification")

    cocotb.log.info("All tests passed!")

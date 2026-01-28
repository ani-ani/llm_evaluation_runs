import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Constants
DATA_WIDTH = 8
MAX_DICT_WORDS = 100  # Reduced for simulation speed, scale to 1000 in real HW
MAX_WORD_LEN = 10
MAX_TARGET_LEN = 20   # Reduced for simulation
CLK_NS = 10
MAX_CYCLES = 50000

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def to_ascii(c):
    return ord(c)

def word_to_digits(word):
    # 2->ABC, 3->DEF, 4->GHI, 5->JKL, 6->MNO, 7->PQRS, 8->TUV, 9->WXYZ
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
    return ''.join(mapping.get(c, '1') for c in word)

def calculate_expected_output(dictionary, target):
    # Python reference implementation for verification
    # Dictionary is list of (word, index)
    # Sort dictionary by digit sequence, then by original index (frequency)
    
    dict_with_digits = [(w, i, word_to_digits(w)) for i, w in enumerate(dictionary)]
    # Sort by digits then by frequency index
    dict_with_digits.sort(key=lambda x: (x[2], x[1]))
    
    # Group by digit sequence
    groups = {}
    for w, idx, digs in dict_with_digits:
        if digs not in groups:
            groups[digs] = []
        groups[digs].append((w, idx))
    
    # DP: Min cost to reach position i
    # dp[i] = (cost, prev_index, word_index, direction, count)
    n = len(target)
    dp = [float('inf')] * (n + 1)
    parent = [None] * (n + 1) # (prev_i, word_text, word_idx_in_group, direction, count)
    dp[0] = 0
    
    for i in range(n):
        if dp[i] == float('inf'): continue
        # Try all prefixes starting at i
        for l in range(1, min(MAX_WORD_LEN, n - i) + 1):
            sub = target[i:i+l]
            digs = word_to_digits(sub)
            
            if digs in groups:
                group = groups[digs] # list of (word, original_idx)
                # Find which word in group matches 'sub'
                # In case of multiple words with same digits, we pick the one with min up/down cost
                best_w_idx = -1
                best_cost = float('inf')
                best_dir = 0
                best_cnt = 0
                
                for w_idx, (w, orig_idx) in enumerate(group):
                    if w == sub:
                        # Calculate up/down cost
                        # pos in sorted list is w_idx
                        # total in list is len(group)
                        cnt_up = w_idx
                        cnt_down = len(group) - w_idx
                        cost, dir_type, count = (cnt_up, 'U', cnt_up) if cnt_up <= cnt_down else (cnt_down, 'D', cnt_down)
                        
                        # Total cost for this segment
                        # Digits cost = len(sub)
                        # Selector cost = cost (unless 0)
                        # 'R' cost = 1 if i > 0 else 0
                        seg_cost = len(sub) + (cost if cost > 0 else 0) + (1 if i > 0 else 0)
                        
                        if seg_cost < best_cost:
                            best_cost = seg_cost
                            best_w_idx = w_idx
                            best_dir = dir_type
                            best_cnt = count
                
                if best_w_idx != -1:
                    if dp[i+l] > dp[i] + best_cost:
                        dp[i+l] = dp[i] + best_cost
                        parent[i+l] = (i, sub, best_w_idx, best_dir, best_cnt)
    
    # Reconstruct
    res = []
    curr = n
    while curr > 0:
        prev_i, word, w_idx, dir_type, count = parent[curr]
        # Up/Down output
        if count > 0:
            res.append(f"{dir_type}({count})")
        # Word digits
        res.append(word_to_digits(word))
        # Right
        if prev_i > 0:
            res.append("R")
        curr = prev_i
    
    res.reverse()
    return ''.join(res)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_sms(dut):
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    if has_signal(dut, 'dictionary_valid'): dut.dictionary_valid.value = 0
    if has_signal(dut, 'query_valid'): dut.query_valid.value = 0
    for _ in range(5): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases from prompt
    test_cases = [
        (['echo'], 'echoecho'),
        (['on', 'm', 'n', 'o'], 'no'),
        (['on', 'm', 'n', 'o'], 'moon')
    ]
    
    for dict_words, target in test_cases:
        cocotb.log.info(f"Testing dict {dict_words} -> target {target}")
        
        # Load Dictionary
        dut.dictionary_valid.value = 1
        for i, w in enumerate(dict_words):
            # Pad word to MAX_WORD_LEN
            w_padded = w.ljust(MAX_WORD_LEN, '\0')
            for j, c in enumerate(w_padded):
                val = 0 if c == '\0' else ord(c)
                # Assuming dut.word_in is an array of signals or a packed signal
                # We check structure: usually it's dut.word_in[j].value or dut.word_in[8*j +: 8]
                # Let's assume it's an unpacked array for simplicity as per typical HDL
                if has_signal(dut, f'word_in_{j}'): # Individual signals
                    getattr(dut, f'word_in_{j}').value = val
                else:
                    # Fallback for packed or other structures is tricky without spec, 
                    # but let's try dut.word_in[j].value if it's an array object
                    try:
                        dut.word_in[j].value = val
                    except Exception:
                         # Assume packed array [7:0] word_in [0:9]
                         # This part is highly dependent on specific HDL structure.
                         # For this benchmark, we'll assume `word_in` is a 80-bit vector
                         # or a multi-dimensional array.
                         # Let's assume `word_in` is a port to be assigned value
                         pass
            
            # We need to trigger the write. The spec might have a write_en or just valid high.
            # Here we toggle valid or wait for clock if it's a register interface.
            # Assuming `dictionary_valid` is a write enable that samples inputs on clock.
            await RisingEdge(dut.clk)
        dut.dictionary_valid.value = 0
        
        # Load Target
        dut.query_valid.value = 1
        w_padded = target.ljust(MAX_WORD_LEN, '\0')
        for j, c in enumerate(w_padded):
            val = 0 if c == '\0' else ord(c)
            if has_signal(dut, f'word_in_{j}'):
                getattr(dut, f'word_in_{j}').value = val
            else:
                try:
                    dut.word_in[j].value = val
                except Exception:
                    pass
        await RisingEdge(dut.clk)
        dut.query_valid.value = 0
        
        # Start Calculation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for Done
        done_cycles = 0
        while True:
            await RisingEdge(dut.clk)
            if has_signal(dut, 'done') and is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                break
            done_cycles += 1
            if done_cycles > MAX_CYCLES:
                raise TestFailure("Timeout waiting for done")
        
        # Read Result
        # The result is likely streamed out on `result_char` with `result_valid`
        output_str = ""
        valid_count = 0
        max_output_len = 50 # Safety limit
        
        # We need to capture the stream
        # Since it's a stream, we might need to keep reading while valid is high
        # Or maybe it's just one cycle per char? 
        # The spec says "Result requires external buffering or streaming"
        # Let's assume we read `result_char` when `result_valid` is high
        
        # We might need to check `result_valid` asynchronously or on clock edges.
        # Typically: on clock edge, if result_valid is high, capture result_char.
        
        # Wait for first valid
        while True:
            await RisingEdge(dut.clk)
            if has_signal(dut, 'result_valid') and is_value_defined(dut.result_valid.value) and int(dut.result_valid.value) == 1:
                if has_signal(dut, 'result_char'):
                    output_str += chr(int(dut.result_char.value))
                break
            done_cycles += 1
            if done_cycles > MAX_CYCLES + 500:
                # Maybe output is empty? 
                break
        
        # Continue capturing if it's a stream
        # Usually there's a `last` signal or it stops when valid goes low
        # Let's loop a few times
        for _ in range(50):
             await RisingEdge(dut.clk)
             if has_signal(dut, 'result_valid') and is_value_defined(dut.result_valid.value) and int(dut.result_valid.value) == 1:
                 if has_signal(dut, 'result_char'):
                    output_str += chr(int(dut.result_char.value))
             else:
                 break

        # Expected
        expected = calculate_expected_output(dict_words, target)
        
        if output_str != expected:
             raise TestFailure(f"Target: {target}\nExpected: {expected}\nGot:      {output_str}")
        else:
             cocotb.log.info(f"Success: {output_str}")

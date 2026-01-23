import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

# ============================================================================
# CONFIGURATION - Adapt to your HDL design
# ============================================================================
DATA_WIDTH = 8
RESULT_WIDTH = 16
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

# Fixed-point parameters for Q8.8
FRAC_BITS = 8
SCALE = 1 << FRAC_BITS

def float_to_fixed(f):
    """Convert float to Q8.8 integer."""
    return int(f * SCALE)

def fixed_to_float(fixed):
    """Convert Q8.8 integer to float."""
    return fixed / SCALE

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
    """Clamp value to fit within specified bit width (unsigned)."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# ============================================================================
# TESTBENCH MAIN
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_expected_score(dut):
    """
    Test the expected score calculator with sample inputs.
    """
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.data_valid.value = 0
    dut.data_last.value = 0
    dut.data_in.value = 0
    
    for _ in range(2):
        await RisingEdge(dut.clk)
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: Sample Input 1
    # t=4, n=4
    # Questions: each with word IDs (we assign arbitrary IDs for the test)
    # Expected output: 2.0 -> fixed point 2.0 * 256 = 512
    
    # Build byte stream for test case 1
    # We'll map words to IDs arbitrarily:
    # Words: ["How", "much", "is", "6", "times", "9", "?", "42", ...]
    # For simplicity, we assign IDs 0..N-1.
    # Since the exact mapping doesn't matter for the algorithm, we use a simple mapping.
    # We'll use the following encoding (manual for test):
    # t=4, n=4
    # Q1: How much is 6 times 9? -> words: How, much, is, 6, times, 9, ? -> 7 words? Actually the last word includes '?'
    # In the problem, the last word has a question mark attached. We treat that as a separate token.
    # For simplicity, we'll use the original words but assign IDs.
    # Since we cannot have strings, we use a predefined mapping.
    # We'll use the following IDs (just for test):
    # 0: How, 1: much, 2: is, 3: 6, 4: times, 5: 9, 6: ?
    # 7: Is, 8: there, 9: intelligent, 10: life, 11: on, 12: Earth, 13: Probably
    # 14: What, 15: the, 16: air, 17: speed, 18: velocity, 19: of, 20: an, 21: unladen, 22: swallow, 23: African?
    # But this is too many. We need to scale down the problem.
    # Let's instead use a simplified test case that matches the second sample.
    
    # We'll use test case 2: t=4, n=3
    # Questions: 
    # 1: What do we send? Code -> words: What, do, we, send, ?
    # 2: What do we want? Accepted -> words: What, do, we, want, ?
    # 3: When do we want it? Now! -> words: When, do, we, want, it, ?
    # This is 5 or 6 words, which exceeds our limit of 4. We need to scale further.
    # Let's design a minimal test case that fits our constraints:
    # t=4, n=3, each question has up to 3 words.
    # Define:
    # Q1: A B? X
    # Q2: A C? Y
    # Q3: D E? Z
    # Words: A=0, B=1, C=2, D=3, E=4, ?=5
    # Then:
    # Q1: [0,1,5] length=3
    # Q2: [0,2,5] length=3
    # Q3: [3,4,5] length=3
    # Expected score? Let's compute manually:
    # Root: 3 questions.
    # First word: A (2 questions) or D (1 question).
    # If first word is D: after 1 second, we know it's Q3, then we can answer after hearing D? But we need to know the answer after hearing the whole question. After D, the set is {Q3}, so we can answer. However, we need to know the answer. Since we know all questions, after hearing D we know it's Q3, so we can answer. So expected score if we wait for D: we get 1 point, but we spent 1 second listening, then answering takes 1 second, total 2 seconds, leaving 2 seconds for more questions. So we can answer Q3 after 2 seconds, then have 2 seconds left for a new question.
    # If first word is A: after 1 second, we have two questions. We cannot answer yet. If we wait another second, we hear the second word: B or C. After second word, we know which question (B->Q1, C->Q2). Then we answer. So for A prefix, we need 2 seconds listening + 1 second answering = 3 seconds per question, leaving 1 second for a new question.
    # With total time 4 seconds, we can answer at most one question from the A prefix (3 seconds) and then with 1 second left, we can answer a D prefix question? But the D prefix question requires 2 seconds (listen D + answer). Not enough.
    # Alternatively, for A prefix, we could answer immediately after first word (before knowing the exact question) with probability 1/2 of being correct. Then we take 1 second answering, leaving 3 seconds. That could be better.
    # We need to compute the optimal expected score using DP. The expected score for this simplified set is left as an exercise.
    # For testing, we will compute the expected score using Python and compare.
    
    # Let's compute the expected score for this case.
    # We'll write a Python function to compute DP.
    
    # Define the questions
    words = ['A', 'B', 'C', 'D', 'E', '?']
    word_to_id = {w:i for i,w in enumerate(words)}
    
    # Q1: A B ?
    q1 = [word_to_id['A'], word_to_id['B'], word_to_id['?']]
    # Q2: A C ?
    q2 = [word_to_id['A'], word_to_id['C'], word_to_id['?']]
    # Q3: D E ?
    q3 = [word_to_id['D'], word_to_id['E'], word_to_id['?']]
    
    # Compute DP for t=4
    # We'll compute using recursion.
    from collections import defaultdict
    
    # Build trie
    class TrieNode:
        def __init__(self):
            self.children = {}  # word_id -> TrieNode
            self.count = 0  # number of questions under this node
            self.q_ids = []  # question indices (optional)
    
    root = TrieNode()
    questions = [q1, q2, q3]
    for idx, q in enumerate(questions):
        node = root
        node.count += 1
        node.q_ids.append(idx)
        for w in q:
            if w not in node.children:
                node.children[w] = TrieNode()
            node = node.children[w]
            node.count += 1
            node.q_ids.append(idx)
    
    # DP memo: (time, node) -> expected score
    # Node identification by path (use object id)
    import sys
    sys.setrecursionlimit(10000)
    
    memo = {}
    def dp(time, node):
        if time == 0:
            return 0.0
        if (time, id(node)) in memo:
            return memo[(time, id(node))]
        k = node.count
        if k == 0:
            return 0.0
        # Option 1: answer now
        # Expected correct if we answer now: probability of being correct = 1/k
        # After answering, we start a new question at root with time-1
        score_answer = (1.0 / k) + dp(time-1, root)
        # Option 2: listen to next word (if there is time to listen)
        # We need to spend 1 second to listen, then we move to a child node.
        # The next word distribution: probability of each child = (child.count)/k
        # We need to consider that if there are no children (leaf), then listening does nothing? Actually if leaf, there are no more words, but the question is finished? In our model, the leaf is after the question mark. At leaf, the set is one question, so we could answer immediately after reaching leaf? But we are considering listening after the question? The model assumes that the host reads the entire question, but Teresa can interrupt at any point. If she reaches the end of the question, she can answer. But the DP model above handles that: at leaf, there are no children, so the only option is to answer.
        # So we compute expected score if we wait: we spend 1 second, then for each possible next word w, we go to child and have time-1 left.
        score_wait = 0.0
        for w, child in node.children.items():
            prob = child.count / k
            score_wait += prob * dp(time-1, child)
        # If there are no children (leaf), then listening yields 0 (cannot wait further)
        best = max(score_answer, score_wait)
        memo[(time, id(node))] = best
        return best
    
    expected = dp(4, root)
    expected_fixed = float_to_fixed(expected)
    
    # Now we will feed this test case to the DUT.
    # We need to encode the input stream.
    # Format: t=4 (1 byte), n=3 (1 byte), then for each question: length L (1 byte), L words (1 byte each), answer (1 byte, we can put 0).
    # We'll use the word IDs defined.
    
    byte_stream = []
    byte_stream.append(4)  # t
    byte_stream.append(3)  # n
    for q in questions:
        byte_stream.append(len(q))  # L
        byte_stream.extend(q)       # words
        byte_stream.append(0)       # answer (ignored)
    
    cocotb.log.info(f"Test case: t=4, n=3, bytes={len(byte_stream)}")
    cocotb.log.info(f"Expected score (float): {expected:.6f}")
    cocotb.log.info(f"Expected score (fixed): {expected_fixed} (0x{expected_fixed:04X})")
    
    # Send bytes to DUT
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for i, byte in enumerate(byte_stream):
        # Wait for DUT to be ready (assuming it has a ready signal)
        # In our specification, we have data_valid and data_last.
        # We'll assume DUT accepts data when data_valid is high.
        # We need to wait for DUT to be ready? We'll just apply data and valid.
        # For simplicity, we assume DUT accepts data every cycle.
        dut.data_in.value = byte
        dut.data_valid.value = 1
        dut.data_last.value = 1 if i == len(byte_stream)-1 else 0
        await RisingEdge(dut.clk)
    
    # Deassert valid
    dut.data_valid.value = 0
    dut.data_last.value = 0
    
    # Wait for done
    done_seen = False
    for cycle in range(MAX_CYCLES):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            done_seen = True
            break
    
    if not done_seen:
        raise TestFailure(f"Timeout: done not asserted after {MAX_CYCLES} cycles")
    
    # Read result
    if not is_value_defined(dut.result.value):
        raise TestFailure("Result is undefined (X/Z)")
    
    result_fixed = int(dut.result.value)
    result_float = fixed_to_float(result_fixed)
    
    cocotb.log.info(f"Result (fixed): 0x{result_fixed:04X} ({result_fixed})")
    cocotb.log.info(f"Result (float): {result_float:.6f}")
    
    # Compare with expected (allow small error due to fixed-point)
    error = abs(result_float - expected)
    if error > 1e-3:
        raise TestFailure(f"Result mismatch: expected {expected:.6f}, got {result_float:.6f}, error {error:.6f}")
    
    cocotb.log.info("Test passed!")

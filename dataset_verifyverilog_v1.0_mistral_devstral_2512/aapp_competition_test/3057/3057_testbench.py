import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import re

# Configuration
DATA_WIDTH = 3  # For word indices (0-7)
MAX_WORDS = 8
MAX_STATEMENTS = 16
CLK_PERIOD_NS = 10

# Helper functions
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    try:
        return int(value)
    except ValueError:
        return default

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

async def reset_dut(dut):
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.statement_valid.value = 0
    dut.last.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def feed_statement(dut, stmt_type, word1, word2, last):
    """Feed one statement to DUT, wait for ready"""
    # Wait for ready
    for _ in range(100):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.ready.value) and int(dut.ready.value) == 1:
            break
    else:
        raise TestFailure("DUT not ready for statement")
    
    # Apply statement
    dut.statement_valid.value = 1
    dut.statement_type.value = stmt_type  # 0 for is, 1 for not
    dut.word1.value = word1
    dut.word2.value = word2
    dut.last.value = 1 if last else 0
    
    await RisingEdge(dut.clk)
    
    # Deassert valid
    dut.statement_valid.value = 0
    dut.last.value = 0

def get_last_three(word):
    """Get last min(3, len(word)) characters"""
    return word[-min(3, len(word)):]

def do_rhyme(word1, word2):
    """Check if two words rhyme"""
    return get_last_three(word1) == get_last_three(word2)

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_consistency_checker(dut):
    """Test the consistency checker with statements and rhyming"""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases
    test_inputs = [
        (
            "4\nherp is derp\nderp is herp\nherp is herp\nderp is derp\n",
            "yes"
        ),
        (
            "3\noskar not lukas\noskar is poptart\nlukas is smart\n",
            "wait what?"
        ),
        (
            "1\nmoo not foo\n",
            "yes"
        ),
        (
            "2\nmoo not foo\noo is blah\n",
            "wait what?"
        ),
    ]
    
    for test_num, (input_str, expected) in enumerate(test_inputs):
        dut._log.info(f"Running test case {test_num+1}")
        
        # Parse input
        lines = input_str.strip().split('\n')
        n = int(lines[0])
        statements = []
        for i in range(1, n+1):
            line = lines[i].strip()
            # Parse: "X is Y" or "X not Y"
            parts = line.split()
            if len(parts) != 3:
                continue
            word1 = parts[0]
            type_token = parts[1]
            word2 = parts[2]
            if type_token == 'is':
                stmt_type = 0
            elif type_token == 'not':
                stmt_type = 1
            else:
                continue
            statements.append((word1, stmt_type, word2))
        
        # Extract all unique words
        unique_words = set()
        for word1, _, word2 in statements:
            unique_words.add(word1)
            unique_words.add(word2)
        
        unique_words = sorted(list(unique_words))
        if len(unique_words) > MAX_WORDS:
            dut._log.warning(f"Too many words ({len(unique_words)}), truncating to {MAX_WORDS}")
            unique_words = unique_words[:MAX_WORDS]
        
        word_to_idx = {word: idx for idx, word in enumerate(unique_words)}
        
        # Compute rhyming pairs
        rhyming_statements = []
        for i in range(len(unique_words)):
            for j in range(i+1, len(unique_words)):
                word_i = unique_words[i]
                word_j = unique_words[j]
                if do_rhyme(word_i, word_j):
                    rhyming_statements.append((word_i, 0, word_j))
        
        # Combine explicit and implicit statements
        all_statements = statements + rhyming_statements
        
        # Feed to DUT
        for idx, (word1, stmt_type, word2) in enumerate(all_statements):
            if word1 not in word_to_idx or word2 not in word_to_idx:
                continue  # Word truncated
            word1_idx = word_to_idx[word1]
            word2_idx = word_to_idx[word2]
            last = (idx == len(all_statements) - 1)
            await feed_statement(dut, stmt_type, word1_idx, word2_idx, last)
        
        # Wait for completion
        await wait_for_done(dut)
        
        # Read result
        result = int(dut.result.value)
        expected_result = 1 if expected.strip() == "yes" else 0
        
        if result != expected_result:
            raise TestFailure(f"Test {test_num+1}: Expected {expected_result}, got {result}")
        
        dut._log.info(f"Test {test_num+1} passed")
        
        # Reset for next test
        await reset_dut(dut)
    
    dut._log.info("All tests passed!")
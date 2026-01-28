import cocotb
from cocotb.triggers import Timer, RisingEdge, ClockCycles
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helper functions
def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except ValueError:
        return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def pack_word(word):
    """Pack a string (max 16 chars) into 128-bit integer (16x8-bit)"""
    packed = 0
    for i, char in enumerate(word[:16]):
        packed |= (ord(char) << (i * 8))
    return packed

def delete_char(word, pos):
    """Remove character at position pos (0-indexed)"""
    return word[:pos] + word[pos+1:]

def write_array(dut, name, values, width):
    """Write values to individual elements of a packed array"""
    for i, v in enumerate(values):
        getattr(dut, f"{name}_{i}").value = clamp_to_width(v, width)

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_typo_detector(dut):
    """
    Test the typo detector with various dictionaries
    """
    # Setup clock and reset
    if has_signal(dut, 'clk'):
        clock = Clock(dut.clk, 10, units='ns')
        cocotb.start_soon(clock.start())
        
        # Reset
        dut.rst_n.value = 0
        if has_signal(dut, 'start'):
            dut.start.value = 0
        for _ in range(2):
            await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        {
            'words': ['hoose', 'hose', 'nose', 'noises', 'noise'],
            'expected_typos': ['hoose', 'noises', 'noise'],
            'desc': 'Sample 1'
        },
        {
            'words': ['hose', 'hoose', 'oose', 'moose'],
            'expected_typos': ['hoose', 'moose'],
            'desc': 'Sample 2'
        },
        {
            'words': ['banana', 'bananana', 'bannanaa', 'orange', 'orangers'],
            'expected_typos': [],
            'desc': 'No typos'
        }
    ]
    
    for tc_idx, test_case in enumerate(test_cases):
        cocotb.log.info(f"\nTest Case {tc_idx+1}: {test_case['desc']}")
        cocotb.log.info(f"Words: {test_case['words']}")
        
        # Prepare inputs
        words = test_case['words']
        n_words = len(words)
        word_lens = [len(w) for w in words]
        word_data = [pack_word(w) for w in words]
        
        # Write to DUT
        if has_signal(dut, 'word_count'):
            dut.word_count.value = n_words
        
        # Write word lengths and data
        for i in range(n_words):
            if has_signal(dut, f'word_len_{i}'):
                getattr(dut, f'word_len_{i}').value = word_lens[i]
            if has_signal(dut, f'word_data_{i}'):
                getattr(dut, f'word_data_{i}').value = word_data[i]
        
        # Zero out remaining words if needed
        for i in range(n_words, 16):
            if has_signal(dut, f'word_len_{i}'):
                getattr(dut, f'word_len_{i}').value = 0
            if has_signal(dut, f'word_data_{i}'):
                getattr(dut, f'word_data_{i}').value = 0
        
        # Start processing
        if has_signal(dut, 'start'):
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
        
        # Wait for processing
        if has_signal(dut, 'busy'):
            while int(dut.busy.value) == 1:
                await RisingEdge(dut.clk)
        else:
            await Timer(500, units='ns')
        
        # Read results
        results = []
        result_indices = []
        
        for i in range(n_words):
            # Read result when done pulses
            await RisingEdge(dut.clk)
            if has_signal(dut, 'done'):
                # Check if done pulse occurs
                done_val = int(dut.done.value) if is_value_defined(dut.done.value) else 0
                if done_val == 1:
                    result_idx = int(dut.result_index.value) if is_value_defined(dut.result_index.value) else 0
                    is_typo = int(dut.is_typo.value) if is_value_defined(dut.is_typo.value) else 0
                    results.append(is_typo == 1)
                    result_indices.append(result_idx)
                    cocotb.log.info(f"Word {result_idx}: '{words[result_idx]}' -> {'Typo' if is_typo else 'OK'}")
            else:
                # Alternative: continuous output
                if has_signal(dut, 'is_typo') and has_signal(dut, 'result_index'):
                    result_idx = int(dut.result_index.value) if is_value_defined(dut.result_index.value) else 0
                    is_typo = int(dut.is_typo.value) if is_value_defined(dut.is_typo.value) else 0
                    results.append(is_typo == 1)
                    result_indices.append(result_idx)
                    cocotb.log.info(f"Word {result_idx}: '{words[result_idx]}' -> {'Typo' if is_typo else 'OK'}")
        
        # Verify results
        # Build expected mapping
        expected_typos_set = set(test_case['expected_typos'])
        
        for i in range(n_words):
            word = words[i]
            is_expected_typo = word in expected_typos_set
            
            # Find result for this word
            found = False
            for j, idx in enumerate(result_indices):
                if idx == i:
                    found = True
                    if results[j] != is_expected_typo:
                        raise TestFailure(
                            f"Test {tc_idx+1}: Word '{word}' expected {'Typo' if is_expected_typo else 'OK'}, "
                            f"got {'Typo' if results[j] else 'OK'}"
                        )
                    break
            
            if not found:
                raise TestFailure(f"Test {tc_idx+1}: No result for word '{word}'")
        
        cocotb.log.info(f"Test {tc_idx+1} PASSED")
        
        # Reset for next test
        if has_signal(dut, 'rst_n'):
            dut.rst_n.value = 0
            await RisingEdge(dut.clk)
            dut.rst_n.value = 1
            await RisingEdge(dut.clk)
    
    cocotb.log.info("All tests passed!")
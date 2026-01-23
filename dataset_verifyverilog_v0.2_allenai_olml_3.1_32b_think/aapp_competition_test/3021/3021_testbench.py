import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure
import random

def char_to_index(c):
    """Convert character to 5-bit index (a=1, b=2, ..., z=26)"""
    return ord(c) - ord('a') + 1

def index_to_char(idx):
    """Convert index back to character"""
    if idx == 0:
        return '_'
    return chr(ord('a') + idx - 1)

def words_to_signal(words, max_len=16):
    """Convert list of words to 8x16 array of 5-bit indices"""
    result = []
    for i in range(8):
        if i < len(words):
            word = words[i]
            for j in range(max_len):
                if j < len(word):
                    result.append(char_to_index(word[j]))
                else:
                    result.append(0)  # Padding
        else:
            result.extend([0] * max_len)
    return result

def run_reference(words, max_char):
    """Reference Python implementation of the algorithm"""
    # Extract constraints
    letters = set()
    for w in words:
        for c in w:
            letters.add(c)
    
    # Map letters to indices 0-15
    letter_list = sorted(letters)
    if not letter_list:
        return "AMBIGUOUS"
    
    # Build constraint graph
    n = len(letter_list)
    adj = [[0] * n for _ in range(n)]
    
    for i in range(len(words) - 1):
        w1, w2 = words[i], words[i+1]
        # Find first difference
        for j in range(min(len(w1), len(w2))):
            if w1[j] != w2[j]:
                idx1 = letter_list.index(w1[j])
                idx2 = letter_list.index(w2[j])
                adj[idx1][idx2] = 1
                break
        else:
            # One is prefix of another
            if len(w1) > len(w2):
                return "IMPOSSIBLE"
    
    # Floyd-Warshall for transitive closure
    reach = [row[:] for row in adj]
    for k in range(n):
        for i in range(n):
            for j in range(n):
                if reach[i][k] and reach[k][j]:
                    reach[i][j] = 1
    
    # Check for cycles
    for i in range(n):
        for j in range(n):
            if i != j and reach[i][j] and reach[j][i]:
                return "IMPOSSIBLE"
    
    # Count topological sorts
    def count_orders():
        # For small n, we can enumerate
        from itertools import permutations
        count = 0
        first_valid = None
        for perm in permutations(range(n)):
            valid = True
            for i in range(n):
                for j in range(n):
                    if adj[i][j]:
                        if perm.index(i) >= perm.index(j):
                            valid = False
                            break
                if not valid:
                    break
            if valid:
                count += 1
                if first_valid is None:
                    first_valid = perm
                if count > 1:
                    return count, None
        return count, first_valid
    
    count, order = count_orders()
    
    if count == 0:
        return "IMPOSSIBLE"
    elif count > 1:
        return "AMBIGUOUS"
    else:
        # Build result string
        result = ""
        for idx in order:
            result += letter_list[idx]
        return result

def format_verilog_input(words, max_char):
    """Format test case as Verilog input signals"""
    signal_values = words_to_signal(words)
    max_idx = char_to_index(max_char)
    num_words = len(words)
    return signal_values, max_idx, num_words

@cocotb.test()
async def test_alphabet_solver_basic(dut):
    """Test basic functionality with sample inputs"""
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: adcb (unique ordering)
    words = ["cab", "cda", "ccc", "badca"]
    max_char = 'd'
    signal_values, max_idx, num_words = format_verilog_input(words, max_char)
    
    # Load inputs
    for i in range(8):
        for j in range(16):
            idx = i * 16 + j
            val = signal_values[idx] if idx < len(signal_values) else 0
            setattr(dut, f'word_chars_{i}', val)
    
    dut.max_char.value = max_idx
    dut.num_words.value = num_words
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 100
    for _ in range(timeout):
        if dut.done.value:
            break
        await RisingEdge(dut.clk)
    
    if not dut.done.value:
        raise TestFailure("Timeout waiting for done")
    
    # Check result
    result_type = int(dut.result_type.value)
    assert result_type == 0, f"Expected ORDERED (0), got {result_type}"
    
    # Read alphabet
    alphabet = []
    for i in range(16):
        val = int(getattr(dut, f'alphabet_{i}').value)
        if val != 0:
            alphabet.append(index_to_char(val))
    
    result = ''.join(alphabet)
    expected = "adcb"
    assert result == expected, f"Expected {expected}, got {result}"
    print(f"Test 1 Passed: {result}")

@cocotb.test()
async def test_alphabet_solver_impossible(dut):
    """Test IMPOSSIBLE case"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 2: IMPOSSIBLE
    words = ["abc", "bca", "cab", "aca"]
    max_char = 'c'
    signal_values, max_idx, num_words = format_verilog_input(words, max_char)
    
    for i in range(8):
        for j in range(16):
            idx = i * 16 + j
            val = signal_values[idx] if idx < len(signal_values) else 0
            setattr(dut, f'word_chars_{i}', val)
    
    dut.max_char.value = max_idx
    dut.num_words.value = num_words
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 100
    for _ in range(timeout):
        if dut.done.value:
            break
        await RisingEdge(dut.clk)
    
    if not dut.done.value:
        raise TestFailure("Timeout waiting for done")
    
    result_type = int(dut.result_type.value)
    assert result_type == 1, f"Expected IMPOSSIBLE (1), got {result_type}"
    print(f"Test 2 Passed: IMPOSSIBLE")

@cocotb.test()
async def test_alphabet_solver_ambiguous(dut):
    """Test AMBIGUOUS case"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 3: AMBIGUOUS
    words = ["dea", "cfb"]
    max_char = 'f'
    signal_values, max_idx, num_words = format_verilog_input(words, max_char)
    
    for i in range(8):
        for j in range(16):
            idx = i * 16 + j
            val = signal_values[idx] if idx < len(signal_values) else 0
            setattr(dut, f'word_chars_{i}', val)
    
    dut.max_char.value = max_idx
    dut.num_words.value = num_words
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 100
    for _ in range(timeout):
        if dut.done.value:
            break
        await RisingEdge(dut.clk)
    
    if not dut.done.value:
        raise TestFailure("Timeout waiting for done")
    
    result_type = int(dut.result_type.value)
    assert result_type == 2, f"Expected AMBIGUOUS (2), got {result_type}"
    print(f"Test 3 Passed: AMBIGUOUS")

@cocotb.test()
async def test_alphabet_solver_complex(dut):
    """Test complex unique ordering case"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 4: edabc
    words = ["ebbce", "dbe", "adcd", "bc", "cd"]
    max_char = 'e'
    signal_values, max_idx, num_words = format_verilog_input(words, max_char)
    
    for i in range(8):
        for j in range(16):
            idx = i * 16 + j
            val = signal_values[idx] if idx < len(signal_values) else 0
            setattr(dut, f'word_chars_{i}', val)
    
    dut.max_char.value = max_idx
    dut.num_words.value = num_words
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 100
    for _ in range(timeout):
        if dut.done.value:
            break
        await RisingEdge(dut.clk)
    
    if not dut.done.value:
        raise TestFailure("Timeout waiting for done")
    
    result_type = int(dut.result_type.value)
    assert result_type == 0, f"Expected ORDERED (0), got {result_type}"
    
    alphabet = []
    for i in range(16):
        val = int(getattr(dut, f'alphabet_{i}').value)
        if val != 0:
            alphabet.append(index_to_char(val))
    
    result = ''.join(alphabet)
    expected = "edabc"
    assert result == expected, f"Expected {expected}, got {result}"
    print(f"Test 4 Passed: {result}")

@cocotb.test()
async def test_alphabet_solver_edge_case(dut):
    """Test edge case with no constraints"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Single word, no constraints
    words = ["abc"]
    max_char = 'c'
    signal_values, max_idx, num_words = format_verilog_input(words, max_char)
    
    for i in range(8):
        for j in range(16):
            idx = i * 16 + j
            val = signal_values[idx] if idx < len(signal_values) else 0
            setattr(dut, f'word_chars_{i}', val)
    
    dut.max_char.value = max_idx
    dut.num_words.value = num_words
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 100
    for _ in range(timeout):
        if dut.done.value:
            break
        await RisingEdge(dut.clk)
    
    if not dut.done.value:
        raise TestFailure("Timeout waiting for done")
    
    # With no constraints, should be AMBIGUOUS
    result_type = int(dut.result_type.value)
    assert result_type == 2, f"Expected AMBIGUOUS (2), got {result_type}"
    print(f"Test 5 Passed: AMBIGUOUS (no constraints)")

@cocotb.test()
async def test_all_cases(dut):
    """Run all test cases and print summary"""
    total_tests = 6
    passed = 0
    
    test_functions = [
        test_alphabet_solver_basic,
        test_alphabet_solver_impossible,
        test_alphabet_solver_ambiguous,
        test_alphabet_solver_complex,
        test_alphabet_solver_edge_case,
        lambda dut: test_alphabet_solver_basic(dut)  # Run basic again
    ]
    
    for i, test_func in enumerate(test_functions):
        try:
            # Reset for each test
            clock = Clock(dut.clk, 10, units="ns")
            cocotb.start_soon(clock.start())
            
            dut.rst_n.value = 0
            await Timer(20, units='ns')
            await RisingEdge(dut.clk)
            dut.rst_n.value = 1
            await RisingEdge(dut.clk)
            
            await test_func(dut)
            passed += 1
        except Exception as e:
            print(f"Test {i+1} failed: {e}")
    
    print(f"
SUMMARY: {passed}/{total_tests} tests passed")
    if passed == total_tests:
        print("ALL TESTS PASSED!")

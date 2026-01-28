import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helpers
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def char_to_bits(c):
    return ord(c) - ord('a') if 'a' <= c <= 'z' else 0

def word_to_bits(word):
    # 5 chars max, 4-bit each
    result = 0
    chars = list(word)
    for i in range(min(5, len(chars))):
        result |= (char_to_bits(chars[i]) & 0xF) << (4 * i)
    return result

def check_rhyme(word1, word2):
    if len(word1) == 0 or len(word2) == 0:
        return False
    k = min(3, len(word1), len(word2))
    return word1[-k:] == word2[-k:]

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_rhyme_consistency(dut):
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(3): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        {
            "name": "Sample 1: Herp/Derp (consistent)",
            "statements": [
                ("herp", "derp", 1),
                ("derp", "herp", 1),
                ("herp", "herp", 1),
                ("derp", "derp", 1)
            ],
            "expected": 1  # yes
        },
        {
            "name": "Sample 2: Oskar contradiction",
            "statements": [
                ("oskar", "lukas", 0),  # not
                ("oskar", "poptart", 1),
                ("lukas", "smart", 1)
            ],
            "expected": 0  # wait what?
        },
        {
            "name": "Sample 3: Moo/Foo no rhyme",
            "statements": [
                ("moo", "foo", 0)  # not
            ],
            "expected": 1  # yes (no contradiction)
        },
        {
            "name": "Sample 4: Moo/Foo with oo rhyme",
            "statements": [
                ("moo", "foo", 0),  # not
                ("oo", "blah", 1)   # oo appears, rhymes with moo/foo
            ],
            "expected": 0  # wait what?
        },
        {
            "name": "Empty input",
            "statements": [],
            "expected": 1  # yes
        },
        {
            "name": "Single statement same word",
            "statements": [("test", "test", 1)],
            "expected": 1  # yes
        },
        {
            "name": "Rhyming words automatic equivalence",
            "statements": [
                ("cat", "bat", 0)  # not, but cat/bat rhyme
            ],
            "expected": 0  # wait what?
        },
        {
            "name": "Chain of equivalences",
            "statements": [
                ("a", "b", 1),
                ("b", "c", 1),
                ("a", "c", 0)  # contradiction
            ],
            "expected": 0  # wait what?
        }
    ]
    
    passed = 0
    failed = 0
    
    for test in test_cases:
        cocotb.log.info(f"Test: {test['name']}")
        try:
            # Reset for each test
            dut.rst_n.value = 0
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
            dut.rst_n.value = 1
            await RisingEdge(dut.clk)
            
            # Set N
            n_stmts = len(test['statements'])
            if has_signal(dut, 'N'):
                dut.N.value = clamp_to_width(n_stmts, 4)
            
            # Set statements
            for i, (w1, w2, is_eq) in enumerate(test['statements']):
                if has_signal(dut, f'word_a_{i}'):
                    getattr(dut, f'word_a_{i}').value = word_to_bits(w1)
                elif has_signal(dut, f'word_a[{i}]'):
                    dut.word_a[i].value = word_to_bits(w1)
                
                if has_signal(dut, f'word_b_{i}'):
                    getattr(dut, f'word_b_{i}').value = word_to_bits(w2)
                elif has_signal(dut, f'word_b[{i}]'):
                    dut.word_b[i].value = word_to_bits(w2)
                
                if has_signal(dut, f'is_eq_{i}'):
                    getattr(dut, f'is_eq_{i}').value = is_eq
                elif has_signal(dut, f'is_eq[{i}]'):
                    dut.is_eq[i].value = is_eq
            
            # Start processing
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            max_cycles = 1000
            done = False
            for cycle in range(max_cycles):
                await RisingEdge(dut.clk)
                if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                    done = True
                    break
            
            if not done:
                raise TestFailure(f"Timeout waiting for done")
            
            # Check result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            expected = test['expected']
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result} (1=yes, 0=wait what?)")
            
            passed += 1
            cocotb.log.info(f"  PASS")
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    if failed > 0:
        raise TestFailure(f"{failed} test(s) failed, {passed} passed")
    
    cocotb.log.info(f"All tests passed: {passed}/{passed + failed}")

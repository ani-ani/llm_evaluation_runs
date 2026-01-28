import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def clamp_to_width(v, width):
    return min((1 << width) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=2000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

def to_string(values):
    result = []
    for v in values:
        if is_value_defined(v):
            result.append(chr(ord('a') + int(v)))
        else:
            result.append('?')
    return ''.join(result)

def is_tolerable(s, p):
    """Check if string s (list of ints 0-25) is tolerable"""
    for i in range(len(s)):
        if s[i] >= p:
            return False
        if i > 0 and s[i] == s[i-1]:
            return False
        if i > 1 and s[i] == s[i-2]:
            return False
    return True

def is_lex_larger(s1, s2):
    """Check if s1 > s2 lexicographically"""
    return s1 > s2

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_next_tolerable(dut):
    # Setup clock
    clk = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clk.start())
    
    # Test cases: (n, p, input_string, expected_output, description)
    test_cases = [
        (3, 3, 'cba', 'NO', 'p=3, cba is last possible'),
        (3, 4, 'cba', 'cbd', 'p=4, increment last'),
        (4, 4, 'abcd', 'abda', 'p=4, abc->abd'),
        (2, 2, 'ab', 'ba', 'p=2, ab->ba'),
        (2, 2, 'ba', 'NO', 'p=2, ba is last'),
        (1, 2, 'a', 'b', 'p=2, single a->b'),
        (1, 2, 'b', 'NO', 'p=2, single b is last'),
        (1, 1, 'a', 'NO', 'p=1, only a'),
        (3, 4, 'cdb', 'dab', 'p=4, cdb->dab'),
        (3, 3, 'cab', 'cba', 'p=3, cab->cba'),
        (3, 26, 'yzx', 'zab', 'p=26, yzx->zab'),
        (2, 4, 'cd', 'da', 'p=4, cd->da'),
    ]
    
    passed = 0
    failed = 0
    
    for idx, (n, p, input_str, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {idx+1}: {desc}")
        
        # Convert string to numeric values
        input_vals = [ord(c) - ord('a') for c in input_str]
        
        await reset_dut(dut)
        
        # Set inputs
        dut.n.value = n
        dut.p.value = p
        
        # Write input string to s_in array
        for i in range(16):
            val = input_vals[i] if i < n else 0
            getattr(dut, f's_in_{i}').value = clamp_to_width(val, 5)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        try:
            await wait_for_done(dut)
        except TestFailure as e:
            cocotb.log.error(f"Test {idx+1} TIMEOUT: {e}")
            failed += 1
            continue
        
        # Read result
        result_vals = []
        valid = int(dut.valid.value) if is_value_defined(dut.valid.value) else 0
        
        for i in range(n):
            if has_signal(dut, f'result_{i}'):
                v = getattr(dut, f'result_{i}').value
                if is_value_defined(v):
                    result_vals.append(int(v))
                else:
                    result_vals.append(0)
            elif hasattr(dut.result, '__getitem__'):
                v = dut.result[i].value
                if is_value_defined(v):
                    result_vals.append(int(v))
                else:
                    result_vals.append(0)
            else:
                result_vals.append(0)
        
        result_str = to_string(result_vals)
        
        if expected == 'NO':
            if valid == 0:
                cocotb.log.info(f"  PASS: Got valid=0 (no solution)")
                passed += 1
            else:
                cocotb.log.error(f"  FAIL: Expected NO but got valid=1 with '{result_str}'")
                failed += 1
        else:
            if valid != 1:
                cocotb.log.error(f"  FAIL: Expected '{expected}' but got valid=0")
                failed += 1
            else:
                if result_str == expected:
                    # Additional validation: check tolerable and larger
                    result_ints = [ord(c) - ord('a') for c in result_str]
                    if is_tolerable(result_ints, p) and is_lex_larger(result_ints, input_vals):
                        cocotb.log.info(f"  PASS: Got '{result_str}'")
                        passed += 1
                    else:
                        cocotb.log.error(f"  FAIL: '{result_str}' is not tolerable or not larger")
                        failed += 1
                else:
                    cocotb.log.error(f"  FAIL: Expected '{expected}' but got '{result_str}'")
                    failed += 1
        
        # Small delay between tests
        await Timer(100, units='ns')
    
    cocotb.log.info(f"\nResults: {passed} passed, {failed} failed")
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
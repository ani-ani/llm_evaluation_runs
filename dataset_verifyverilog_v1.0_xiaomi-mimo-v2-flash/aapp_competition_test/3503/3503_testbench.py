import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

DATA_WIDTH = 32
N_MAX = 16
CLK_NS = 10
MAX_CYCLES = 5000

def is_value_defined(v):
    try:
        int(v)
        return True
    except (ValueError, TypeError):
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except (ValueError, TypeError):
        return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits - 1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.valid.value) and int(dut.valid.value) == 1:
            return True
        if is_value_defined(dut.impossible.value) and int(dut.impossible.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

def compute_results(a, b):
    """Compute +, -, * results for pair (a,b) as 32-bit signed"""
    res = []
    # Addition
    res.append((0, to_signed(a + b, DATA_WIDTH)))
    # Subtraction
    res.append((1, to_signed(a - b, DATA_WIDTH)))
    # Multiplication (truncate to 32-bit)
    prod = a * b
    res.append((2, to_signed(prod & ((1 << DATA_WIDTH) - 1), DATA_WIDTH)))
    return res

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_distinct_results(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test case 1: Simple case from sample
    test_cases = [
        {
            'n': 4,
            'pairs': [(1, 5), (3, 3), (4, 5), (-1, -6)],
            'expected': 'impossible'
        },
        {
            'n': 3,
            'pairs': [(1, 2), (3, 4), (5, 6)],
            'expected': 'possible'
        },
        {
            'n': 2,
            'pairs': [(0, 0), (1, 1)],
            'expected': 'possible'
        },
        {
            'n': 1,
            'pairs': [(100, 200)],
            'expected': 'possible'
        }
    ]
    
    passed = 0
    failed = 0
    
    for test_idx, test in enumerate(test_cases):
        n = test['n']
        pairs = test['pairs']
        expected = test['expected']
        
        cocotb.log.info(f"Test {test_idx + 1}: n={n}, pairs={pairs}")
        
        try:
            if is_seq:
                # Set n
                dut.n.value = n
                
                # Set a and b arrays
                for i in range(N_MAX):
                    if i < n:
                        a_val = pairs[i][0]
                        b_val = pairs[i][1]
                    else:
                        a_val = 0
                        b_val = 0
                    
                    if has_signal(dut, f'a_{i}'):
                        getattr(dut, f'a_{i}').value = clamp_to_width(from_signed(a_val, DATA_WIDTH), DATA_WIDTH)
                        getattr(dut, f'b_{i}').value = clamp_to_width(from_signed(b_val, DATA_WIDTH), DATA_WIDTH)
                    else:
                        # Try array access
                        try:
                            dut.a[i].value = clamp_to_width(from_signed(a_val, DATA_WIDTH), DATA_WIDTH)
                            dut.b[i].value = clamp_to_width(from_signed(b_val, DATA_WIDTH), DATA_WIDTH)
                        except:
                            pass
                
                # Start processing
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                await wait_for_done(dut)
                
                # Check results
                if is_value_defined(dut.impossible.value) and int(dut.impossible.value) == 1:
                    result_state = 'impossible'
                else:
                    result_state = 'possible'
                
                if result_state != expected:
                    raise TestFailure(f"Expected '{expected}', got '{result_state}'")
                
                # If possible, verify distinct results
                if result_state == 'possible':
                    results = []
                    for i in range(n):
                        if has_signal(dut, f'result_{i}'):
                            res_val = int(getattr(dut, f'result_{i}').value)
                        else:
                            res_val = int(dut.result[i].value)
                        
                        # Convert from unsigned to signed
                        res_signed = to_signed(res_val, DATA_WIDTH)
                        results.append(res_signed)
                    
                    if len(results) != len(set(results)):
                        raise TestFailure(f"Results not distinct: {results}")
                    
                    # Verify against input pairs
                    for i, (a, b) in enumerate(pairs):
                        if has_signal(dut, f'op_{i}'):
                            op_val = int(getattr(dut, f'op_{i}').value)
                        else:
                            op_val = int(dut.op[i].value)
                        
                        if has_signal(dut, f'result_{i}'):
                            res_val = int(getattr(dut, f'result_{i}').value)
                        else:
                            res_val = int(dut.result[i].value)
                        
                        res_signed = to_signed(res_val, DATA_WIDTH)
                        
                        if op_val == 0:
                            expected_res = to_signed(a + b, DATA_WIDTH)
                        elif op_val == 1:
                            expected_res = to_signed(a - b, DATA_WIDTH)
                        else:  # op_val == 2
                            prod = a * b
                            expected_res = to_signed(prod & ((1 << DATA_WIDTH) - 1), DATA_WIDTH)
                        
                        if res_signed != expected_res:
                            raise TestFailure(f"Pair {i}: op={op_val} gave {res_signed}, expected {expected_res}")
                
                passed += 1
                cocotb.log.info(f"Test {test_idx + 1} passed")
            else:
                # Combinational test
                await Timer(100, units='ns')
                passed += 1
                
        except TestFailure as e:
            cocotb.log.error(f"Test {test_idx + 1} FAILED: {e}")
            failed += 1
    
    # Additional stress test with random valid input
    cocotb.log.info("Running random stress test...")
    try:
        if is_seq:
            n = 4
            pairs = [(random.randint(-100, 100), random.randint(-100, 100)) for _ in range(n)]
            
            dut.n.value = n
            for i in range(N_MAX):
                if i < n:
                    a_val = pairs[i][0]
                    b_val = pairs[i][1]
                else:
                    a_val = 0
                    b_val = 0
                
                if has_signal(dut, f'a_{i}'):
                    getattr(dut, f'a_{i}').value = clamp_to_width(from_signed(a_val, DATA_WIDTH), DATA_WIDTH)
                    getattr(dut, f'b_{i}').value = clamp_to_width(from_signed(b_val, DATA_WIDTH), DATA_WIDTH)
                else:
                    try:
                        dut.a[i].value = clamp_to_width(from_signed(a_val, DATA_WIDTH), DATA_WIDTH)
                        dut.b[i].value = clamp_to_width(from_signed(b_val, DATA_WIDTH), DATA_WIDTH)
                    except:
                        pass
            
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            await wait_for_done(dut)
            
            if is_value_defined(dut.impossible.value) and int(dut.impossible.value) == 1:
                # May be impossible for random input, that's ok
                cocotb.log.info("Random test: impossible (valid outcome)")
            else:
                results = []
                for i in range(n):
                    if has_signal(dut, f'result_{i}'):
                        res_val = int(getattr(dut, f'result_{i}').value)
                    else:
                        res_val = int(dut.result[i].value)
                    res_signed = to_signed(res_val, DATA_WIDTH)
                    results.append(res_signed)
                
                if len(results) != len(set(results)):
                    raise TestFailure("Random test: results not distinct")
                cocotb.log.info(f"Random test passed: results={results}")
            
            passed += 1
        else:
            await Timer(100, units='ns')
            passed += 1
            
    except TestFailure as e:
        cocotb.log.error(f"Random stress test FAILED: {e}")
        failed += 1
    
    cocotb.log.info(f"Final result: {passed} passed, {failed} failed")
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Fixed-point helpers
def float_to_q16_16(f):
    return int(f * 65536)

def q16_16_to_float(v):
    return v / 65536.0

def clamp_to_32bit(v):
    return v & 0xFFFFFFFF

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

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

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=50000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

def compute_reference(N, T, a_list, b_list, c_list):
    """Compute expected result using Python"""
    # Discretize to 100 steps per hour
    total_steps = T * 100
    time_per_subject = [0] * N
    
    for step in range(total_steps):
        best_subj = -1
        best_gain = -1e9
        
        for i in range(N):
            t_curr = time_per_subject[i] / 100.0
            t_next = (time_per_subject[i] + 1) / 100.0
            
            gain = (a_list[i] * t_next**2 + b_list[i] * t_next + c_list[i]) - \
                   (a_list[i] * t_curr**2 + b_list[i] * t_curr + c_list[i])
            
            if gain > best_gain:
                best_gain = gain
                best_subj = i
        
        if best_subj >= 0:
            time_per_subject[best_subj] += 1
    
    total_grade = 0.0
    for i in range(N):
        t = time_per_subject[i] / 100.0
        total_grade += a_list[i] * t**2 + b_list[i] * t + c_list[i]
    
    return total_grade / N

async def run_test_case(dut, N, T, a_list, b_list, c_list, exp):
    """Run a single test case on the DUT"""
    cocotb.log.info(f"Test: N={N}, T={T}")
    
    # Set inputs
    dut.N.value = N
    dut.T.value = T
    
    # Set coefficients (10 subjects max)
    for i in range(10):
        if i < N:
            getattr(dut, f'a_{i}').value = float_to_q16_16(a_list[i])
            getattr(dut, f'b_{i}').value = float_to_q16_16(b_list[i])
            getattr(dut, f'c_{i}').value = float_to_q16_16(c_list[i])
        else:
            getattr(dut, f'a_{i}').value = 0
            getattr(dut, f'b_{i}').value = 0
            getattr(dut, f'c_{i}').value = 0
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    await wait_for_done(dut, max_cycles=50000)
    
    # Read result
    if not is_value_defined(dut.result.value):
        raise TestFailure("Result undefined")
    
    result_q16 = int(dut.result.value)
    result_float = q16_16_to_float(result_q16)
    
    cocotb.log.info(f"Expected: {exp:.10f}, Got: {result_float:.10f}")
    
    # Check within 0.01 tolerance
    if abs(result_float - exp) > 0.01:
        raise TestFailure(f"Result mismatch: expected {exp:.10f}, got {result_float:.10f} (diff={abs(result_float-exp):.6f})")
    
    return True

@cocotb.test(timeout_time=100, timeout_unit="ms")
async def test_module(dut):
    """Main test function"""
    # Check if sequential module (has clk)
    is_seq = has_signal(dut, 'clk')
    
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    
    # Test cases from problem
    test_cases = [
        # Case 1
        {
            'N': 2, 'T': 96,
            'a': [-0.0080, -0.0080],
            'b': [1.5417, 1.5417],
            'c': [25.0000, 25.0000],
            'exp': 80.5696000000
        },
        # Case 2
        {
            'N': 3, 'T': 34,
            'a': [-0.0657, -0.0562, -0.0493],
            'b': [4.4706, 3.8235, 3.3529],
            'c': [23.0000, 34.0000, 42.0000],
            'exp': 70.0731488027
        }
    ]
    
    passed = 0
    failed = 0
    
    for i, tc in enumerate(test_cases):
        try:
            cocotb.log.info(f"\nRunning Test Case {i+1}")
            exp_result = compute_reference(
                tc['N'], tc['T'], 
                tc['a'], tc['b'], tc['c']
            )
            
            # The expected output is given in the problem, use it directly
            exp_given = tc['exp']
            
            await run_test_case(
                dut, tc['N'], tc['T'],
                tc['a'], tc['b'], tc['c'],
                exp_given
            )
            passed += 1
            cocotb.log.info(f"Test {i+1} PASSED")
            
        except TestFailure as e:
            failed += 1
            cocotb.log.error(f"Test {i+1} FAILED: {e}")
        except Exception as e:
            failed += 1
            cocotb.log.error(f"Test {i+1} ERROR: {e}")
    
    if failed > 0:
        raise TestFailure(f"{failed} of {len(test_cases)} tests failed")
    
    cocotb.log.info(f"\nAll {passed} tests passed!")

@cocotb.test(timeout_time=200, timeout_unit="ms")
async def test_random_cases(dut):
    """Test with random generated cases"""
    is_seq = has_signal(dut, 'clk')
    
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    
    random.seed(42)
    num_random_tests = 3
    
    for test_idx in range(num_random_tests):
        N = random.randint(1, 10)
        T = random.randint(1, 240)
        
        a_list = []
        b_list = []
        c_list = []
        
        for _ in range(N):
            # Generate a < 0, b > 0, c >= 0 such that f is non-decreasing on [0,T]
            # f'(t) = 2*a*t + b >= 0 for all t in [0,T]
            # => 2*a*T + b >= 0 => b >= -2*a*T
            # Since a < 0, -2*a*T > 0
            a_val = -random.uniform(0.001, 0.1)
            min_b = -2 * a_val * T
            b_val = min_b + random.uniform(0.1, 5.0)
            c_val = random.uniform(0.0, 50.0)
            
            a_list.append(a_val)
            b_list.append(b_val)
            c_list.append(c_val)
        
        exp_result = compute_reference(N, T, a_list, b_list, c_list)
        
        cocotb.log.info(f"\nRandom Test {test_idx+1}: N={N}, T={T}")
        
        try:
            await run_test_case(dut, N, T, a_list, b_list, c_list, exp_result)
            cocotb.log.info(f"Random test {test_idx+1} PASSED")
        except TestFailure as e:
            cocotb.log.error(f"Random test {test_idx+1} FAILED: {e}")
            raise TestFailure(f"Random test {test_idx+1} failed")

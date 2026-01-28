import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 16
ARRAY_SIZE = 16
CLK_NS = 10
MAX_CYCLES = 300

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def read_result_array(dut):
    results = []
    for i in range(ARRAY_SIZE):
        val = getattr(dut, f'result[{i}]').value if hasattr(dut, f'result[{i}]') else None
        if val is None:
            # Check if result is indexed access
            try:
                val = dut.result[i].value
            except:
                break
        if is_value_defined(val):
            results.append(int(val))
        else:
            results.append(0)
    return results

def python_func(n):
    """Reference Python implementation"""
    result = []
    fact = 1
    summ = 0
    for i in range(1, n + 1):
        fact *= i
        summ += i
        if i % 2 == 0:  # even index
            result.append(fact)
        else:  # odd index
            result.append(summ)
    return result

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_factorial_sum_array(dut):
    # Setup clock and reset
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases
    test_cases = [
        (1, [1]),
        (3, [1, 2, 6]),
        (5, [1, 2, 6, 24, 15]),
        (7, [1, 2, 6, 24, 15, 720, 28]),
        (16, None)  # Large test
    ]
    
    passed = 0
    failed = 0
    
    for i, (n, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: N={n}")
        
        try:
            # Compute expected if None
            if expected is None:
                expected = python_func(n)
                cocotb.log.info(f"Expected for N={n}: {expected}")
            
            # Set inputs
            dut.n.value = n
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read results
            result_array = await read_result_array(dut)
            
            # Validate
            if not result_array:
                raise TestFailure("Result array empty or inaccessible")
            
            # Check only first n elements
            for j in range(n):
                if j >= len(result_array):
                    raise TestFailure(f"Result array too short: {len(result_array)} < {n}")
                actual = result_array[j]
                expected_val = expected[j] if j < len(expected) else 0
                
                # Handle overflow clamping for factorial
                clamped_expected = clamp_to_width(expected_val, 16)
                
                if actual != clamped_expected:
                    raise TestFailure(
                        f"Index {j}: expected {clamped_expected}, got {actual} "
                        f"(original expected {expected_val})"
                    )
            
            # Check remaining elements are zero (or at least consistent)
            for j in range(n, min(len(result_array), ARRAY_SIZE)):
                if result_array[j] != 0:
                    raise TestFailure(f"Non-zero value at unused index {j}: {result_array[j]}")
            
            cocotb.log.info(f"  PASS: Results match expected")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
    
    cocotb.log.info(f"All tests passed: {passed}")

import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
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

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=100):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=100, timeout_unit="ms")
async def test_orac_median(dut):
    CLK_NS = 10
    DATA_WIDTH = 8
    ARRAY_SIZE = 16
    
    # Setup clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational design
        dut.rst_n.value = 1
    
    # Test cases: (array, k, expected_result, description)
    test_cases = [
        ([1, 5, 2, 6, 1], 3, 0, "First example: no k in array"),
        ([6], 6, 1, "Single element already k"),
        ([1, 2, 3], 2, 1, "k exists with adjacent >="),
        ([3, 1, 2, 3], 3, 0, "No adjacent >= pairs"),
        ([1, 2, 3, 4, 5, 6, 7, 8, 9, 10], 3, 1, "Has adjacent >= pairs"),
        ([2, 2, 2, 2], 2, 1, "All equal to k"),
        ([5, 1, 5], 5, 1, "k with neighbors >="),
        ([1, 1, 1], 2, 0, "k not in array"),
        ([3, 1, 1, 1, 4, 1, 4], 3, 1, "k with distance-2 >= neighbors"),
    ]
    
    passed = 0
    failed = 0
    
    for test_idx, (arr, k, expected, desc) in enumerate(test_cases):
        n = len(arr)
        cocotb.log.info(f"Test {test_idx+1}: {desc} (n={n}, k={k})")
        
        try:
            # Set inputs
            if has_signal(dut, 'k'):
                dut.k.value = clamp_to_width(k, DATA_WIDTH)
            else:
                # Check if k is part of data input
                pass
            
            # Set array elements individually
            for i in range(ARRAY_SIZE):
                if i < n:
                    # Handle different array access patterns
                    if hasattr(dut, f'a_{i}'):
                        getattr(dut, f'a_{i}').value = clamp_to_width(arr[i], DATA_WIDTH)
                    elif hasattr(dut, 'a') and hasattr(dut.a, '__getitem__'):
                        dut.a[i].value = clamp_to_width(arr[i], DATA_WIDTH)
                else:
                    # Initialize unused elements to 0
                    if hasattr(dut, f'a_{i}'):
                        getattr(dut, f'a_{i}').value = 0
                    elif hasattr(dut, 'a') and hasattr(dut.a, '__getitem__'):
                        dut.a[i].value = 0
            
            # Set length
            if has_signal(dut, 'n'):
                dut.n.value = clamp_to_width(n, 5)
            
            # Start computation if sequential
            if has_signal(dut, 'clk') and has_signal(dut, 'start'):
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut, max_cycles=10)
            else:
                # Combinational or single cycle
                await Timer(10, units='ns')
            
            # Read result
            if has_signal(dut, 'result'):
                result_val = int(dut.result.value)
                if result_val != expected:
                    raise TestFailure(f"Expected {expected}, got {result_val}")
            elif hasattr(dut, 'done'):
                # Check if done indicates success
                result_val = int(dut.done.value)
                # For designs where done=1 means yes
                expected_done = 1 if expected else 0
                if result_val != expected_done:
                    raise TestFailure(f"Expected done={expected_done}, got {result_val}")
            else:
                raise TestFailure("No result signal found")
            
            passed += 1
            cocotb.log.info(f"  PASS")
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
    
    cocotb.log.info(f"All {passed} tests passed!")

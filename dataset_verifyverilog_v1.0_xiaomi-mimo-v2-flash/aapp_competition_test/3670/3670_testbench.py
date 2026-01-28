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

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

# Constants
DATA_WIDTH = 10
MAX_N = 8
CLK_NS = 10

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

def to_packed(values, width=10):
    res = 0
    for i, v in enumerate(values):
        # Map large values to fit 10-bit as per prompt scaling spec
        if v >= 1024:
            v = v >> 1  # Simple scaling
        v = clamp_to_width(v, width)
        res |= v << (i * width)
    return res

def get_divisors(num):
    divs = []
    for i in range(2, num + 1):
        if num % i == 0:
            divs.append(i)
    return divs

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_find_modulus(dut):
    # Setup Clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)

    # Test cases based on prompt examples and constraints
    test_cases = [
        # Input: [list of numbers], Expected: set of M values
        ([6, 34, 38], {2, 4}),
        ([5, 17, 23, 14, 83], {3}),
        ([10, 20, 30], {2, 3, 5, 10}),  # Divisors of 20 (20-10), 10, 20
        ([100, 102], {2}), # Diff 2
    ]

    for i, (nums, expected_ms) in enumerate(test_cases):
        # Prepare input
        n = len(nums)
        packed_data = to_packed(nums)
        
        cocotb.log.info(f"Test {i+1}: N={n}, Num={nums}")
        
        # Apply inputs
        dut.num_data.value = packed_data
        dut.N.value = n
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Collect results
        found_ms = []
        timeout_counter = 0
        max_timeout = 2000
        
        # Wait for valid outputs or done
        while True:
            await RisingEdge(dut.clk)
            timeout_counter += 1
            if timeout_counter > max_timeout:
                raise TestFailure(f"Timeout waiting for done in test {i+1}")
            
            # Check if valid
            if is_value_defined(dut.valid.value) and int(dut.valid.value) == 1:
                if is_value_defined(dut.result_M.value):
                    found_ms.append(int(dut.result_M.value))
            
            # Check if done
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                break
        
        # Verify
        found_set = set(found_ms)
        if found_set != expected_ms:
            raise TestFailure(f"Test {i+1} failed. Expected {expected_ms}, got {found_set}")
        
        # Reset for next test
        await reset_dut(dut)
        await Timer(10, units='ns')

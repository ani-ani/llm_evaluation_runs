import cocotb
from cocotb.triggers import Timer, RisingEdge
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

def clamp_to_width(v, bits):
    if bits == 0: return 0
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=20000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def provide_input(dut, numbers, data_width=64):
    """
    Provides numbers serially. Assumes dut.input_ready is monitored.
    """
    for num in numbers:
        # Wait for input_ready
        timeout = 0
        while True:
            if has_signal(dut, 'input_ready') and is_value_defined(dut.input_ready.value) and int(dut.input_ready.value) == 1:
                break
            await RisingEdge(dut.clk)
            timeout += 1
            if timeout > 1000:
                raise TestFailure("Timeout waiting for input_ready")
        
        dut.data_in.value = clamp_to_width(num, data_width)
        await RisingEdge(dut.clk)
        # Note: The module should sample data_in. We can add a small check if needed.
        dut.data_in.value = 0  # Clear after valid cycle

# Python reference implementation
def max_xor_subset(numbers):
    # Build basis
    basis = []
    for x in numbers:
        temp = x
        for b in basis:
            temp = min(temp, temp ^ b)
        if temp > 0:
            basis.append(temp)
            basis.sort(reverse=True)
    
    # Max XOR sum from basis
    res = 0
    for b in basis:
        if (res ^ b) > res:
            res ^= b
    return res

@cocotb.test(timeout_time=10, timeout_unit="ms")
async def test_max_xor_subset(dut):
    # Parameters based on spec
    DATA_WIDTH = 64
    MAX_NUMS = 16
    CLK_NS = 10
    
    # Setup Clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    # Setup Inputs
    if has_signal(dut, 'rst_n'):
        await reset_dut(dut)
    
    # Test Cases
    test_cases = [
        ([1, 3, 5], 7),
        ([2, 6, 4, 8], 14),
        ([1], 1),
        ([5, 5, 5], 5)
    ]
    
    # Add random tests
    for _ in range(5):
        nums = [random.randint(1, 1000) for _ in range(random.randint(1, 8))]
        exp = max_xor_subset(nums)
        test_cases.append((nums, exp))

    for i, (nums, exp) in enumerate(test_cases):
        cocotb.log.info(f"Running Test Case {i+1}: {nums} (Expected: {exp})")
        
        # 1. Assert Start
        if has_signal(dut, 'start'):
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
        
        # 2. Provide num_count if it exists
        if has_signal(dut, 'num_count'):
            dut.num_count.value = len(nums)
            await RisingEdge(dut.clk)
        
        # 3. Feed numbers
        await provide_input(dut, nums, DATA_WIDTH)
        
        # 4. Wait for done
        if has_signal(dut, 'done'):
            await wait_for_done(dut)
        else:
            await Timer(1000, units='ns')
        
        # 5. Check result
        if not has_signal(dut, 'result'):
            raise TestFailure("Output signal 'result' not found")
            
        result_val = int(dut.result.value)
        if result_val != exp:
            raise TestFailure(f"Test {i+1} failed. Expected {exp}, got {result_val}")
        
        cocotb.log.info(f"Test {i+1} Passed. Result: {result_val}")
        
        # Reset for next test
        if has_signal(dut, 'rst_n'):
            await reset_dut(dut)

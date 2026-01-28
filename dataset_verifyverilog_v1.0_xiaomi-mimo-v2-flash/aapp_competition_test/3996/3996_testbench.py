import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
from functools import reduce

MOD = 1000000007
PHI = 1000000006

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

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    if has_signal(dut, 'a_valid'):
        dut.a_valid.value = 0
    if has_signal(dut, 'input_done'):
        dut.input_done.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=100000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.result_valid.value) and int(dut.result_valid.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def send_inputs(dut, numbers):
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Determine parity and product modulo PHI in Python for verification
    parity = 0
    prod_mod = 1
    for num in numbers:
        prod_mod = (prod_mod * (num % PHI)) % PHI
        if num % 2 == 0:
            parity = 1
            
    for num in numbers:
        dut.a_val.value = clamp_to_width(num, 60)
        dut.a_valid.value = 1
        await RisingEdge(dut.clk)
    
    dut.a_valid.value = 0
    dut.input_done.value = 1
    await RisingEdge(dut.clk)
    dut.input_done.value = 0
    
    return prod_mod, parity

async def verify_result(dut, numbers):
    prod_mod, parity = await send_inputs(dut, numbers)
    await wait_for_done(dut)
    
    x_val = int(dut.x.value)
    y_val = int(dut.y.value)
    
    # Python Verification
    inv2 = pow(2, MOD - 2, MOD)
    inv3 = pow(3, MOD - 2, MOD)
    
    pow2_val = pow(2, prod_mod, MOD)
    q_expected = (pow2_val * inv2) % MOD
    
    if parity == 1: # Even
        x_expected = (q_expected + 1) * inv3 % MOD
    else: # Odd
        x_expected = (q_expected - 1 + MOD) * inv3 % MOD
        
    cocotb.log.info(f"Inputs: {numbers}")
    cocotb.log.info(f"Computed (x,y): ({x_val}, {y_val})")
    cocotb.log.info(f"Expected (x,y): ({x_expected}, {q_expected})")
    
    if x_val != x_expected or y_val != q_expected:
        raise TestFailure(f"Mismatch for inputs {numbers}")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_cups_and_key(dut):
    # Clock setup
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)
    
    # Test case 1: Input [2] -> n=2 (even)
    # 2^2 = 4. q = 4/2 = 2. x = (2+1)/3 = 1. Result: 1/2
    await verify_result(dut, [2])
    
    # Test case 2: Input [1, 1, 1] -> n=1*1*1=1 (odd)
    # 2^1 = 2. q = 2/2 = 1. x = (1-1)/3 = 0. Result: 0/1
    await verify_result(dut, [1, 1, 1])
    
    # Test case 3: Input [3] -> n=3 (odd)
    # 2^3 = 8. q = 4. x = (4-1)/3 = 1. Result: 1/4
    await verify_result(dut, [3])
    
    # Test case 4: Large random inputs (simulated)
    # Just to stress the accumulation phase
    large_nums = [1000000000, 999999999, 1000000001]
    await verify_result(dut, large_nums)
    
    # Test case 5: Mixed even/odd
    await verify_result(dut, [5, 2, 3]) # 30 turns (even)
    
    cocotb.log.info("All tests passed!")

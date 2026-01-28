import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

MOD = 10**9 + 7

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
    raise TestFailure(f"Timeout waiting for done")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_morse_counting(dut):
    # Setup clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    
    # Test cases from problem
    test_inputs = [
        [1, 1, 1],
        [1, 0, 1, 0, 1],
        [1, 1, 0, 0, 0, 1, 1, 0, 1]
    ]
    
    expected_outputs = [
        [1, 3, 7],
        [1, 4, 10, 22, 43],
        [1, 3, 10, 24, 51, 109, 213, 421, 833]
    ]

    for case_idx, (bits, exps) in enumerate(zip(test_inputs, expected_outputs)):
        cocotb.log.info(f"Running Test Case {case_idx+1}")
        
        # Reset for new case
        if has_signal(dut, 'rst_n'):
            await reset_dut(dut)
        
        for i, bit in enumerate(bits):
            # Drive inputs
            dut.new_bit.value = bit
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Check result
            if not is_value_defined(dut.result.value):
                raise TestFailure(f"Result undefined at step {i}")
            
            result = int(dut.result.value)
            expected = exps[i]
            
            # Handle potential modulo wrapping in simple HW implementations
            # or exact values. The test expects exact match as per problem statement.
            if result != expected:
                # Check if it matches modulo (sometimes HW sums modulo intermediate steps)
                # The problem asks for modulo 10^9+7.
                if (result % MOD) != (expected % MOD):
                     raise TestFailure(f"Case {case_idx+1}, Step {i}: Expected {expected}, Got {result}")
            
            cocotb.log.info(f"Case {case_idx+1} Step {i}: Got {result} (Expected {expected})")
            await RisingEdge(dut.clk) # Small gap

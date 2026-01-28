import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

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

# Helper to pack ASCII string into integer array for HDL
def str_to_vals(s):
    # Remove newline
    s = s.strip()
    # Convert chars to ints
    return [ord(c) for c in s]

async def wait_for_done(dut, max_cycles=20000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

# The Python solution reference to verify HDL
def python_solve(factor_str):
    factor_str = factor_str.strip()
    factors = []
    # Parse pairs of digits
    for i in range(0, len(factor_str), 2):
        val = int(factor_str[i:i+2])
        factors.append(val)
    
    # Compute K (clamping if too large, but for testbench we use Python ints)
    K = 1
    for f in factors:
        K *= f
    
    # Find min cost M + N where M*N = K
    min_cost = float('inf')
    import math
    limit = int(math.sqrt(K))
    for M in range(1, limit + 1):
        if K % M == 0:
            N = K // M
            cost = M + N
            if cost < min_cost:
                min_cost = cost
    return min_cost

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_min_cost_servers(dut):
    # Setup Clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational logic
        await Timer(100, units='ns')

    # Test Cases
    test_cases = [
        ("020302", 7),   # 2, 3, 2 -> K=12. Divisors: 1+12=13, 2+6=8, 3+4=7. Result 7.
        ("1311", 24),    # 13, 11 -> K=143. Divisors: 1+143=144, 11+13=24. Result 24.
        ("11", 12)       # 11 -> K=11. Divisors: 1+11=12. Result 12.
    ]

    passed = 0
    failed = 0

    for factor_str, expected_cost in test_cases:
        cocotb.log.info(f"Testing input: {factor_str}")
        
        # Calculate expected using Python logic
        actual_expected = python_solve(factor_str)
        cocotb.log.info(f"Python verified result: {actual_expected}")
        
        # Prepare input
        vals = str_to_vals(factor_str)
        str_len = len(vals)
        
        # Drive inputs
        if has_signal(dut, 'factor_str'):
            # Assuming factor_str is an array of signals or a packed value
            # Strategy: If it's a vector like input [699:0], we usually set .value = packed_int
            # If it's an array of wires dut.factor_str[i], we assign individually.
            # Let's try to detect if it's a list of attributes
            try:
                # Check if it's a flat list of signals like factor_str_0, factor_str_1...
                # Or if it's dut.factor_str[i]
                elem = getattr(dut, 'factor_str')
                # If it's a modifiable object, try array assignment (cocotb handles lists)
                # However, the rule says NEVER dut.arr.value = [list].
                # So we iterate.
                # Check if it supports indexing
                try:
                    elem[0] # It's an array
                    for i, v in enumerate(vals):
                        if i < 700: # Safety limit
                            elem[i].value = v
                except (TypeError, AttributeError):
                    # It's likely a single logic vector. Pack it.
                    # Not likely for a 700-bit string input, but let's handle standard vector
                    packed = 0
                    for i, v in enumerate(vals):
                        packed |= (v & 0xFF) << (i * 8)
                    # Assuming input width is enough
                    elem.value = packed
            except Exception as e:
                cocotb.log.error(f"Failed to drive factor_str: {e}")
        
        if has_signal(dut, 'str_len'):
            dut.str_len.value = str_len
            
        if has_signal(dut, 'start'):
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            await wait_for_done(dut)
        else:
            await Timer(1000, units='ns')
            
        if has_signal(dut, 'result'):
            result_val = int(dut.result.value)
            # The HDL result should be the minimum cost
            if result_val != actual_expected:
                cocotb.log.error(f"FAIL: Input '{factor_str}'. Expected {actual_expected}, got {result_val}")
                failed += 1
            else:
                cocotb.log.info(f"PASS: Input '{factor_str}'. Result {result_val}")
                passed += 1
        else:
            cocotb.log.error("No 'result' signal found")
            failed += 1

    if failed > 0:
        raise TestFailure(f"{failed} tests failed out of {passed+failed}")

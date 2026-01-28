import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    await Timer(10, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=2000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# Python reference implementation
def lcs_of_three(X, Y, Z):
    m, n, o = len(X), len(Y), len(Z)
    L = [[[0 for _ in range(o+1)] for _ in range(n+1)] for _ in range(m+1)]
    for i in range(m+1):
        for j in range(n+1):
            for k in range(o+1):
                if i == 0 or j == 0 or k == 0:
                    L[i][j][k] = 0
                elif X[i-1] == Y[j-1] and X[i-1] == Z[k-1]:
                    L[i][j][k] = L[i-1][j-1][k-1] + 1
                else:
                    L[i][j][k] = max(L[i-1][j][k], L[i][j-1][k], L[i][j][k-1])
    return L[m][n][o]

# Test data preparation
def str_to_arr(s, max_len=8):
    return [ord(c) for c in s] + [0]*(max_len - len(s))

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_lcs_three(dut):
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)

    # Test cases
    test_cases = [
        ('AGGT12', '12TXAYB', '12XBA'),
        ('Reels', 'Reelsfor', 'ReelsforReels'),
        ('abcd1e2', 'bc12ea', 'bd1ea')
    ]

    for i, (s1, s2, s3) in enumerate(test_cases):
        cocotb.log.info(f"Running Test Case {i+1}: S1='{s1}', S2='{s2}', S3='{s3}'")
        
        expected = lcs_of_three(s1, s2, s3)
        
        # Prepare inputs
        arr_a = str_to_arr(s1)
        arr_b = str_to_arr(s2)
        arr_c = str_to_arr(s3)
        
        # Write string arrays
        for j in range(8):
            dut.str_a[j].value = clamp_to_width(arr_a[j], 8)
            dut.str_b[j].value = clamp_to_width(arr_b[j], 8)
            dut.str_c[j].value = clamp_to_width(arr_c[j], 8)
        
        # Write lengths
        dut.len_a.value = len(s1)
        dut.len_b.value = len(s2)
        dut.len_c.value = len(s3)
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        await wait_for_done(dut)
        
        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Test {i+1}: Result signal undefined")
            
        result = int(dut.result.value)
        if result != expected:
            raise TestFailure(f"Test {i+1}: Expected LCS length {expected}, got {result}")
        
        # Small delay between tests
        await Timer(100, units='ns')
        await RisingEdge(dut.clk)

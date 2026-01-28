import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import numpy as np

# Configuration
FIXED_BITS = 32
CLK_PERIOD_NS = 10

# Helper functions

def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    try:
        return int(value)
    except ValueError:
        return default

def to_signed(val, bits):
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    if val < 0:
        return val + (1 << bits)
    return val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    if value < 0:
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# Expected cost computation using matrix exponentiation
def expected_cost(N, P):
    num_states = 101
    q = 1.0 - P
    T = np.zeros((num_states, num_states))
    C = np.zeros(num_states)
    for i in range(num_states):
        if i == 0:
            C[i] = 5.0
            T[i, 100] = 1.0
        else:
            C[i] = 5.0 * (q ** i)
            for k in range(1, i):
                prob = P * (q ** (k-1))
                T[i, i - k] += prob
            T[i, 0] = P * (q ** (i-1))
            T[i, 100] = q ** i
    M = np.zeros((102, 102))
    M[0:101, 0:101] = T
    M[0:101, 101] = C
    M[101, 101] = 1.0
    M_exp = np.linalg.matrix_power(M, N)
    W0 = np.zeros(102)
    W0[101] = 1.0
    W_N = M_exp @ W0
    return W_N[100]

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_pokemon_go_cost(dut):
    """Test the Pokemon Go cost module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (N, P)
    test_cases = [
        (50, 0.125),
        (201, 1.0),
        (7, 0.0),
    ]
    
    for N, P in test_cases:
        dut._log.info(f"Testing N={N}, P={P}")
        
        # Compute expected cost
        expected = expected_cost(N, P)
        
        # Convert P to scaled integer (P * 1000)
        P_scaled = int(round(P * 1000))
        
        # Set inputs
        dut.N.value = N
        dut.P_scaled.value = P_scaled
        
        # Pulse start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 10000  # cycles
        for _ in range(timeout):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                break
        else:
            raise TestFailure(f"Timeout waiting for done for N={N}, P={P}")
        
        # Read cost
        if not is_value_defined(dut.cost.value):
            raise TestFailure(f"Cost is undefined")
        
        cost_fixed = int(dut.cost.value)
        # Convert to float
        cost_float = cost_fixed / (2 ** FIXED_BITS)
        
        # Check relative error
        error = abs(cost_float - expected) / max(1e-9, expected)
        if error > 1e-6:
            raise TestFailure(f"Cost mismatch: expected {expected}, got {cost_float}, error {error}")
        
        dut._log.info(f"  PASS: cost = {cost_float}")
    
    dut._log.info("All tests passed")
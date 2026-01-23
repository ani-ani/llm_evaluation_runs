import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration
MAX_BUGS = 2
MAX_TIME = 8
DATA_WIDTH = 64
FRACTION_WIDTH = 32
CLK_PERIOD_NS = 10

# Helper functions
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def from_float_to_q32_32(f):
    return int(f * (1 << FRACTION_WIDTH))

def from_int_to_q32_32(i):
    return i << FRACTION_WIDTH

def to_float_from_q32_32(q):
    return q / (1 << FRACTION_WIDTH)

def compute_expected(B, T, f, bugs):
    """Reference DP implementation."""
    state_size = (T+2) ** B
    dp = [[0.0] * state_size for _ in range(T+1)]
    f_power = [1.0] * (T+1)
    for k in range(1, T+1):
        f_power[k] = f_power[k-1] * f
    
    def encode_state(states):
        idx = 0
        for i, s in enumerate(states):
            idx += s * ((T+2) ** i)
        return idx
    
    def decode_state(idx):
        states = []
        for i in range(B):
            states.append(idx % (T+2))
            idx //= (T+2)
        return states
    
    for t in range(T-1, -1, -1):
        for state_idx in range(state_size):
            states = decode_state(state_idx)
            best = 0.0
            for bug in range(B):
                if states[bug] == T+1:
                    continue
                k = states[bug]
                p_current = bugs[bug][0] * f_power[k]
                states_success = states.copy(); states_success[bug] = T+1
                states_failure = states.copy(); states_failure[bug] = min(k+1, T)
                state_success_idx = encode_state(states_success)
                state_failure_idx = encode_state(states_failure)
                value = (p_current * (bugs[bug][1] + dp[t+1][state_success_idx]) +
                        (1-p_current) * dp[t+1][state_failure_idx])
                if value > best:
                    best = value
            dp[t][state_idx] = best
    initial_state = encode_state([0]*B)
    return dp[0][initial_state]

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_bug_fixing(dut):
    """Main testbench."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        {
            'B': 1,
            'T': 2,
            'f': 0.95,
            'bugs': [(0.70, 50)],
            'expected': 44.975
        },
        {
            'B': 2,
            'T': 2,
            'f': 0.5,
            'bugs': [(0.75, 100), (0.75, 20)],
            'expected': 95.625
        }
    ]
    
    for tc in test_cases:
        # Set inputs
        dut.B.value = tc['B']
        dut.T.value = tc['T']
        dut.f.value = from_float_to_q32_32(tc['f'])
        
        for i, (p, s) in enumerate(tc['bugs']):
            dut.p[i].value = from_float_to_q32_32(p)
            dut.s[i].value = from_int_to_q32_32(s)
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        done = False
        for _ in range(1000):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                done = True
                break
        
        if not done:
            raise TestFailure("Done not asserted")
        
        # Read and check output
        result_q = int(dut.expected_value.value)
        result = to_float_from_q32_32(result_q)
        expected = tc['expected']
        
        if abs(result - expected) > 1e-6:
            raise TestFailure(f"Expected {expected}, got {result}")
        
        dut._log.info(f"Test passed: {result}")
        await RisingEdge(dut.clk)

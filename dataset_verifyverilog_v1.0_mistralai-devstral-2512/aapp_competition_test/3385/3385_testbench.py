import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Constants
MOD = 10**9 + 7
MAX_N = 16
DATA_WIDTH = 8
CLK_NS = 10
MAX_CYCLES = 5000

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

@cocotb.test(timeout_time=100, timeout_unit="ms")
async def test_halloween(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        # Reset
        dut.rst_n.value = 0
        if has_signal(dut, 'start'): dut.start.value = 0
        for _ in range(2): await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

    # Test cases: (N, inputs_matrix, expected_result)
    # Input matrix format: list of [l, r, x]
    test_cases = [
        (5, 
         [[1,0,0],[1,0,1],[3,0,1],[3,0,0],[3,0,1]], 
         0), # Sample 1
        (5, 
         [[3,1,1],[0,3,1],[1,3,1],[1,2,1],[0,4,1]], 
         4), # Sample 2
    ]

    passed = 0
    failed = 0

    for idx, (n, constraints, expected) in enumerate(test_cases):
        cocotb.log.info(f"Running Test Case {idx+1}: N={n}")
        
        # Write N
        if has_signal(dut, 'n_in'):
            dut.n_in.value = n
        
        # Write constraints
        # We assume the interface has an array of 3 inputs per child or flattened
        # Example: dut.l_i[i], dut.r_i[i], dut.x_i[i]
        # Or dut.data_in packed. Let's assume individual ports for clarity.
        for i in range(n):
            if has_signal(dut, f'l_i[{i}]'):
                dut.l_i[i].value = constraints[i][0]
                dut.r_i[i].value = constraints[i][1]
                dut.x_i[i].value = constraints[i][2]
            elif has_signal(dut, f'l_i_{i}'):
                getattr(dut, f'l_i_{i}').value = constraints[i][0]
                getattr(dut, f'r_i_{i}').value = constraints[i][1]
                getattr(dut, f'x_i_{i}').value = constraints[i][2]

        # Start
        if is_seq:
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            done = False
            for _ in range(MAX_CYCLES):
                await RisingEdge(dut.clk)
                if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                    done = True
                    break
            
            if not done:
                cocotb.log.error(f"Test {idx+1} timeout")
                failed += 1
                continue
        else:
            # Combinational
            await Timer(100, units='ns')

        # Check result
        if not has_signal(dut, 'result'):
            cocotb.log.error("Result signal missing")
            failed += 1
            continue

        result = int(dut.result.value)
        if result != expected:
            cocotb.log.error(f"Test {idx+1} Failed: Expected {expected}, Got {result}")
            failed += 1
        else:
            cocotb.log.info(f"Test {idx+1} Passed")
            passed += 1

    if failed > 0:
        raise TestFailure(f"{failed} tests failed")

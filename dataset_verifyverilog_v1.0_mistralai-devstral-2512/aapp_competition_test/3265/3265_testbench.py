import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
ARRAY_SIZE = 8
CLK_NS = 10
MAX_CYCLES = 2000
TARGET_PROB = int(0.95 * 65536)  # 62259 in Q16.16

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

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_markov_chain(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        await Timer(100, units='ns')

    # Test case 1: N=3, L=1, expecting T=2
    await test_case(dut, N=3, L=1, transitions=[
        [0, 11, 9],
        [1, 0, 10],
        [0, 0, 0]
    ], expected_T=2, desc="Sample 1")

    # Test case 2: N=4, L=3, expecting -1
    await test_case(dut, N=4, L=3, transitions=[
        [0, 1, 0, 19],
        [0, 0, 2, 0],
        [0, 5, 0, 3],
        [0, 0, 0, 0]
    ], expected_T=None, desc="Sample 2")

    # Test case 3: N=3, L=100, expecting -1 (probability decays)
    await test_case(dut, N=3, L=100, transitions=[
        [0, 1, 0],
        [1, 0, 0],
        [0, 0, 0]
    ], expected_T=None, desc="Sample 3")

async def test_case(dut, N, L, transitions, expected_T, desc):
    cocotb.log.info(f"Running test: {desc} (N={N}, L={L})")
    
    # Set inputs
    dut.N.value = N
    dut.L.value = L
    
    # Write transition matrix
    for i in range(8):
        for j in range(8):
            val = transitions[i][j] if i < N and j < N else 0
            signal_name = f'transitions_{i}_{j}'
            if has_signal(dut, signal_name):
                getattr(dut, signal_name).value = clamp_to_width(val, 8)
            else:
                # If array, assume individual signals are named arr_{i}_{j}
                pass
    
    # Start
    if has_signal(dut, 'start'):
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        await wait_for_done(dut)
    else:
        await Timer(500, units='ns')
    
    # Check result
    if has_signal(dut, 'result_valid'):
        valid = int(dut.result_valid.value)
        T_out = int(dut.T_out.value) if has_signal(dut, 'T_out') else 0
        
        if expected_T is not None:
            if valid != 1:
                raise TestFailure(f"{desc}: Expected valid=1, got {valid}")
            if T_out != expected_T:
                raise TestFailure(f"{desc}: Expected T={expected_T}, got {T_out}")
            cocotb.log.info(f"PASS: {desc} - Found T={T_out}")
        else:
            if valid != 0:
                raise TestFailure(f"{desc}: Expected valid=0, got {valid} (T={T_out})")
            cocotb.log.info(f"PASS: {desc} - Correctly no solution")
    else:
        raise TestFailure("Module missing result_valid signal")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): 
        if has_signal(dut, 'clk'): await RisingEdge(dut.clk)
        else: await Timer(10, units='ns')
    dut.rst_n.value = 1
    if has_signal(dut, 'clk'): await RisingEdge(dut.clk)
    else: await Timer(10, units='ns')

async def wait_for_done(dut, max_cycles=1000):
    if not has_signal(dut, 'done'):
        await Timer(2000, units='ns')
        return
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return
    raise TestFailure(f"Timeout after {max_cycles} cycles")

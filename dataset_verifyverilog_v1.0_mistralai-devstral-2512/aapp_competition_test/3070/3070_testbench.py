import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 16
ARRAY_SIZE = 16
CLK_NS = 10
MAX_CYCLES = 1000

# Helpers

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
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

async def write_train_data(dut, trains, N, M):
    dut.N.value = N
    dut.M.value = M
    for i in range(min(M, ARRAY_SIZE)):
        X, S, T, L = trains[i]
        getattr(dut, f'train_X_{i}').value = clamp_to_width(X, 4)
        getattr(dut, f'train_S_{i}').value = clamp_to_width(S, DATA_WIDTH)
        getattr(dut, f'train_T_{i}').value = clamp_to_width(T, DATA_WIDTH)
        getattr(dut, f'train_L_{i}').value = clamp_to_width(L, DATA_WIDTH)
    # Initialize unused to 0
    for i in range(M, ARRAY_SIZE):
        getattr(dut, f'train_X_{i}').value = 0
        getattr(dut, f'train_S_{i}').value = 0
        getattr(dut, f'train_T_{i}').value = 0
        getattr(dut, f'train_L_{i}').value = 0

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_earliest_train(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases from problem
    test_cases = [
        (2, 3, [(1, 1800, 9000, 1800), (1, 2000, 9200, 1600), (1, 2200, 9400, 1400)], 1800, "Sample 1"),
        (2, 2, [(1, 1800, 3600, 1800), (1, 1900, 3600, 1600)], 0, "Sample 2 (impossible, output 0)"),
        (3, 2, [(1, 10, 20, 1), (2, 20, 30, 0)], 10, "Sample 3")
    ]
    
    passed = 0
    failed = 0
    
    for i, (N, M, trains, exp, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            if is_seq:
                await write_train_data(dut, trains, N, M)
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(100, units='ns')
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            result = int(dut.result.value)
            if result != exp:
                raise TestFailure(f"Expected {exp}, got {result}")
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}"); failed += 1
    
    if failed: raise TestFailure(f"{failed} tests failed")
    cocotb.log.info(f"Passed: {passed}/{len(test_cases)}")
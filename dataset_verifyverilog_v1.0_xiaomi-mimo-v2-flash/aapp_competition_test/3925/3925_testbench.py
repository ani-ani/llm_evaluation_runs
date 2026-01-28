import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Constants based on scaled requirements
MAX_LEN = 64
DATA_WIDTH = 1  # 1 bit per char ('b'/'w')
CLK_NS = 10
MAX_CYCLES = 2000

# --- Mandatory Helpers ---
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
    if has_signal(dut, 'data_valid'): dut.data_valid.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# --- Helper to convert string to bit sequence and feed serially ---
async def feed_string(dut, s):
    # Map 'b' to 1, 'w' to 0 (arbitrary but consistent)
    # Or 'b' to 1, 'w' to 0
    bits = [1 if c == 'b' else 0 for c in s]
    
    dut.start.value = 1
    dut.len_in.value = len(s)
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    for bit in bits:
        dut.data_in.value = bit
        dut.data_valid.value = 1
        await RisingEdge(dut.clk)
        # Wait if ready is low (if flow control exists)
        # If no ready signal, assume we can drive data every cycle
        # Assuming simple interface for now where valid drives data
    
    dut.data_valid.value = 0

# --- Helper to compute expected result in Python ---
def compute_expected(s):
    # Logic: find longest alternating sequence in s+s
    n = len(s)
    if n == 0: return 0
    s_doubled = s + s
    max_run = 1
    curr_run = 1
    
    for i in range(1, len(s_doubled)):
        if s_doubled[i] != s_doubled[i-1]:
            curr_run += 1
            if curr_run > max_run:
                max_run = curr_run
        else:
            curr_run = 1
    
    # Cap at n (cannot select more pieces than exist)
    return min(max_run, n)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_zebra(dut):
    # Setup Clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational path (if any), wait a bit
        await Timer(100, units='ns')

    # Test Cases (Scaled down inputs for testing speed)
    test_cases = [
        ("bwwwbwwbw", 5),
        ("bwwbwwb", 3),
        ("bwb", 3),
        ("bbbbwbwwbbww", 4),
        ("bw", 2),
        ("b", 1),
        ("w", 1),
        ("bwbwbwbwbwb", 11), # Full alternating
        ("wwww", 1), # All same
    ]

    passed = 0
    failed = 0

    for i, (s_in, exp) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: Input='{s_in}' Expected={exp}")
        try:
            # Feed input
            await feed_string(dut, s_in)
            
            # Wait for done
            if has_signal(dut, 'done'):
                await wait_for_done(dut)
            else:
                # If combinational, just wait a bit
                await Timer(100, units='ns')

            # Read Result
            if not has_signal(dut, 'result'):
                raise TestFailure("Result signal not found")
            
            result_val = int(dut.result.value)
            
            if result_val != exp:
                raise TestFailure(f"Expected {exp}, got {result_val}")
            
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: Test {i+1} ({s_in}) - {e}")
            failed += 1
        
        # Reset between tests if sequential
        if has_signal(dut, 'clk'):
            await reset_dut(dut)
        else:
            await Timer(100, units='ns')

    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed+failed}")
    
    cocotb.log.info(f"All {passed} tests passed!")

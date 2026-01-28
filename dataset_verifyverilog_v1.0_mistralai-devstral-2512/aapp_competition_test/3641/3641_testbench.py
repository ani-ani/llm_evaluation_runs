import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Constants based on adaptation
DATA_WIDTH = 8
MAX_N = 16
MAX_K = 4
MAX_SUM = 4095  # 12-bit limit
CLK_NS = 10
MAX_CYCLES = 256

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

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def write_beads(dut, beads):
    # beads is list of integers, length <= 16
    for i, w in enumerate(beads):
        if i < MAX_N:
            dut.beads[i].value = clamp_to_width(w, DATA_WIDTH)
    # Pad remaining with 0
    for i in range(len(beads), MAX_N):
        dut.beads[i].value = 0

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_necklace_split(dut):
    # Setup clock if sequential
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational logic only
        await Timer(100, units='ns')
    
    # Test cases: (k, n, beads_list, expected_result)
    # Adapted to small scale
    test_cases = [
        (3, 4, [1, 2, 2, 1], True),   # YES
        (3, 4, [2, 2, 4, 1], False),  # NO
        (2, 4, [1, 1, 2, 0], True),   # YES: 2+0=2, 1+1=2
        (2, 4, [1, 2, 1, 1], False),  # NO: total=5 odd
        (4, 4, [1, 1, 1, 1], True),   # YES: each gets 1
        (2, 2, [10, 10], True),       # YES
        (2, 2, [10, 11], False),      # NO: total=21 odd
        (3, 6, [1,1,1,2,2,2], True),  # YES: total=9, target=3
        (4, 8, [1,2,3,4,5,6,7,8], False), # NO: total=36, target=9, can we find? No in circular
        (1, 5, [5,5,5,5,5], True),    # YES: trivial
    ]
    
    passed = 0
    failed = 0
    
    for idx, (k, n, beads, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {idx+1}: k={k}, n={n}, beads={beads}, expect={'YES' if expected else 'NO'}")
        
        try:
            # Write inputs
            if has_signal(dut, 'n'):
                dut.n.value = clamp_to_width(n, 4)
            if has_signal(dut, 'k'):
                dut.k.value = clamp_to_width(k, 4)
            
            await write_beads(dut, beads)
            
            # Trigger start
            if has_signal(dut, 'start'):
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                # Combinational: wait for signals to settle
                await Timer(100, units='ns')
            
            # Read result
            if not has_signal(dut, 'result'):
                raise TestFailure("Result signal missing")
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value) == 1
            if result != expected:
                raise TestFailure(f"Expected {'YES' if expected else 'NO'}, got {'YES' if result else 'NO'}")
            
            passed += 1
            cocotb.log.info(f"  PASS: Result={'YES' if result else 'NO'}")
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed")

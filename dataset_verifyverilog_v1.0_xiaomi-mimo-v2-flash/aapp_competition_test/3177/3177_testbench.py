import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 4
ARRAY_SIZE = 4
MAX_SWAPS = 6
CLK_NS = 10

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

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_min_swaps(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases: scaled to N=4 where possible
    test_cases = [
        # Input: perm [p0,p1,p2,p3], swaps [(a0,b0)...], num_swaps, expected result
        ([2,1,3,4], [(1,2)], 1, 1),  # Sample1 scaled
        ([2,1,3,4], [(1,3),(2,3)], 2, 3),  # Sample2 scaled (3 swaps to [1,2,3,4])
        ([1,2,3,4], [], 0, 0),  # Already sorted
        ([3,1,2,4], [(1,2),(2,3)], 2, 2),  # Simple 2 swaps
    ]
    
    passed = failed = 0
    for i, (perm, swaps, num_swaps, exp) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: perm={perm}, swaps={swaps}, exp={exp}")
        try:
            # Write permutation
            for j in range(4):
                getattr(dut, f'perm_{j}').value = clamp_to_width(perm[j]-1, DATA_WIDTH)
            
            # Write swaps
            for j in range(MAX_SWAPS):
                if j < len(swaps):
                    a, b = swaps[j]
                    getattr(dut, f'swap_a_{j}').value = clamp_to_width(a-1, 3)
                    getattr(dut, f'swap_b_{j}').value = clamp_to_width(b-1, 3)
                else:
                    getattr(dut, f'swap_a_{j}').value = 0
                    getattr(dut, f'swap_b_{j}').value = 0
            
            if has_signal(dut, 'num_swaps'):
                dut.num_swaps.value = clamp_to_width(num_swaps, 3)
            
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut, max_cycles=1000)
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
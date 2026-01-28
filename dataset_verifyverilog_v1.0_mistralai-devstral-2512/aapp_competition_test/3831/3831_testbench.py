import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
ARRAY_SIZE = 16
CLK_NS = 10
MAX_CYCLES = 256

# MANDATORY HELPERS
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
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

# ARRAY WRITERS
def write_array_s(dut, vals):
    for i, v in enumerate(vals):
        dut.s_arr[i].value = clamp_to_width(v, DATA_WIDTH)

def write_array_g(dut, vals):
    for i, v in enumerate(vals):
        dut.g_arr[i].value = clamp_to_width(v, DATA_WIDTH)

def pack_result(vals, bits=8):
    r = 0
    for i, v in enumerate(vals):
        r |= (v & ((1<<bits)-1)) << (i*bits)
    return r

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_mayor(dut):
    # Check if sequential
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        raise TestFailure("Sequential module required")
    
    # Test cases scaled for 8-bit values, n≤16
    test_cases = [
        # (n, s_list, g_list, expected_total, expected_s_prime, desc)
        (3, [4,4,4], [5,5,10], 16, [9,9,10], "Example 1"),
        (4, [1,100,1,100], [100,1,100,1], 202, [101,101,101,101], "Example 2"),
        (3, [1,100,1], [1,100,1], -1, None, "Example 3 impossible"),
        (1, [1], [0], 0, [1], "Single no lawn"),
        (1, [1], [10], 10, [11], "Single lawn"),
        (2, [2,1], [2,1], 2, [3,2], "Two parts"),
        (2, [2,0], [0,0], 0, [2,1], "Two static"),
        (3, [1,2,3], [3,1,0], 4, [4,3,3], "Increasing"),
    ]
    
    passed = failed = 0
    
    for i, (n, s_vals, g_vals, exp_total, exp_s_prime, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Write inputs
            dut.n.value = n
            write_array_s(dut, s_vals)
            write_array_g(dut, g_vals)
            
            # Start computation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read results
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            
            if exp_total == -1:
                # Expect -1 (0xFFFF in 16-bit)
                if result != 0xFFFF:
                    raise TestFailure(f"Expected -1 (0xFFFF), got {result}")
            else:
                if result != exp_total:
                    raise TestFailure(f"Expected total {exp_total}, got {result}")
                
                # Verify s_prime
                for j in range(n):
                    if not is_value_defined(dut.s_prime_arr[j].value):
                        raise TestFailure(f"s_prime[{j}] undefined")
                    sp = int(dut.s_prime_arr[j].value)
                    if sp != exp_s_prime[j]:
                        raise TestFailure(f"s_prime[{j}] expected {exp_s_prime[j]}, got {sp}")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed")
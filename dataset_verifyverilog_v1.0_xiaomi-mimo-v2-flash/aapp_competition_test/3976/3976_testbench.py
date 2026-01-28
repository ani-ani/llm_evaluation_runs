import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH, ARRAY_SIZE, CLK_NS, MAX_CYCLES = 6, 16, 10, 1000

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

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_sereja_subsequence(dut):
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational circuit
        await Timer(100, units='ns')
    
    test_cases = [
        # (n, m, p, a_list, b_list, expected_count, expected_positions)
        (5, 3, 1, [1,2,3,2,1], [1,2,3], 2, [1,3]),
        (6, 3, 2, [1,3,2,2,3,1], [1,2,3], 2, [1,2]),
        (3, 5, 1, [1,1,1], [1,1,1,1,1], 0, []),
        (1, 1, 1, [1], [1], 1, [1]),
        (2, 2, 1, [1,2], [2,1], 1, [1]),
    ]
    
    passed = failed = 0
    
    for i, (n, m, p, a_list, b_list, exp_count, exp_pos) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: n={n}, m={m}, p={p}")
        try:
            # Clamp values to 6-bit
            a_clamped = [clamp_to_width(x, 6) for x in a_list]
            b_clamped = [clamp_to_width(x, 6) for x in b_list]
            
            # Set inputs
            if has_signal(dut, 'n'):
                dut.n.value = n
                dut.m.value = m
                dut.p.value = p
            
            # Write arrays
            for j in range(ARRAY_SIZE):
                if j < len(a_clamped):
                    getattr(dut, f'a_{j}').value = a_clamped[j]
                else:
                    getattr(dut, f'a_{j}').value = 0
                
                if j < len(b_clamped):
                    getattr(dut, f'b_{j}').value = b_clamped[j]
                else:
                    getattr(dut, f'b_{j}').value = 0
            
            if has_signal(dut, 'clk'):
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(100, units='ns')
            
            # Check result
            if not is_value_defined(dut.result_count.value):
                raise TestFailure("Result count undefined")
            
            actual_count = int(dut.result_count.value)
            
            if actual_count != exp_count:
                raise TestFailure(f"Expected count {exp_count}, got {actual_count}")
            
            # Read positions
            actual_pos = []
            for j in range(min(actual_count, ARRAY_SIZE)):
                pos_val = getattr(dut, f'result_positions_{j}').value
                if is_value_defined(pos_val):
                    actual_pos.append(int(pos_val))
            
            if set(actual_pos) != set(exp_pos):
                raise TestFailure(f"Expected positions {exp_pos}, got {actual_pos}")
            
            passed += 1
            cocotb.log.info(f"PASS: {exp_count} positions {exp_pos}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed+failed}")
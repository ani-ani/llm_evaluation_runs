import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH, ARRAY_SIZE, CLK_NS, MAX_CYCLES = 8, 16, 10, 1000

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

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def write_sequence(dut, seq, width):
    for i, v in enumerate(seq):
        if i < ARRAY_SIZE:
            dut.seq[i].value = clamp_to_width(v, width)

def compute_critical_mask(seq):
    n = len(seq)
    if n == 0: return 0, 0
    
    # Forward LIS DP
    dp_f = [1] * n
    for i in range(n):
        for j in range(i):
            if seq[j] < seq[i] and dp_f[j] + 1 > dp_f[i]:
                dp_f[i] = dp_f[j] + 1
    
    # Backward LIS DP
    dp_b = [1] * n
    for i in range(n-1, -1, -1):
        for j in range(i+1, n):
            if seq[j] > seq[i] and dp_b[j] + 1 > dp_b[i]:
                dp_b[i] = dp_b[j] + 1
    
    lis_len = max(dp_f) if dp_f else 0
    if lis_len == 0: return 0, 0
    
    # Count how many positions can be part of LIS of length lis_len
    # An element is critical if removing it reduces LIS length
    # For permutation: element is critical if it's the only one at its value position
    # that can be in a LIS
    
    # Alternative: check for each element if it appears in all LIS
    # In permutation, each value appears once. Critical if:
    # dp_f[i] + dp_b[i] - 1 == lis_len AND
    # it's the only element with that dp_f[i] at that LIS position
    
    # For simplicity: element is critical if it's necessary for LIS
    # Count occurrences of each dp_f value
    count_by_len = [0] * (lis_len + 1)
    for i in range(n):
        if dp_f[i] + dp_b[i] - 1 == lis_len:
            count_by_len[dp_f[i]] += 1
    
    mask = 0
    count = 0
    for i in range(n):
        if dp_f[i] + dp_b[i] - 1 == lis_len and count_by_len[dp_f[i]] == 1:
            value = seq[i]
            mask |= (1 << (value - 1))
            count += 1
    
    return mask, count

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_critical_elements(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    test_cases = [
        ([1, 3, 2, 4], 0x0009, 2, "example 1"),
        ([1, 2, 3, 4, 5], 0x001F, 5, "example 2"),
        ([2, 1, 4, 3], 0x0000, 0, "example 3"),
        ([4, 3, 1, 2], 0x0006, 2, "example 4")
    ]
    
    passed = failed = 0
    
    for i, (seq, exp_mask, exp_count, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            n = len(seq)
            await write_sequence(dut, seq, DATA_WIDTH)
            
            if is_seq:
                dut.len.value = n
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                dut.len.value = n
                await Timer(100, units='ns')
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            actual_mask = result >> 8
            actual_count = result & 0xFF
            
            if actual_mask != exp_mask:
                raise TestFailure(f"Mask mismatch: expected 0x{exp_mask:04X}, got 0x{actual_mask:04X}")
            if actual_count != exp_count:
                raise TestFailure(f"Count mismatch: expected {exp_count}, got {actual_count}")
            
            passed += 1
            cocotb.log.info(f"PASS: mask=0x{actual_mask:04X}, count={actual_count}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed")
    else:
        cocotb.log.info(f"All {passed} tests passed")
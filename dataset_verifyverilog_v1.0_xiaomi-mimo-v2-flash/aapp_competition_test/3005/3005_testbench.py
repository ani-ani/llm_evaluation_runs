import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
MAX_LEN = 16
CLK_NS = 10
MAX_CYCLES = 3000

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
    if has_signal(dut, 'write_enable'): dut.write_enable.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if has_signal(dut, 'done') and is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def load_string(dut, s):
    # Load characters into the module
    chars = [ord(c) for c in s.strip()]
    length = len(chars)
    
    if has_signal(dut, 'len'):
        dut.len.value = length
        
    for i, val in enumerate(chars):
        if has_signal(dut, 'addr'):
            dut.addr.value = i
        if has_signal(dut, 'char_in'):
            dut.char_in.value = clamp_to_width(val, 8)
        if has_signal(dut, 'write_enable'):
            dut.write_enable.value = 1
            await RisingEdge(dut.clk)
            dut.write_enable.value = 0
        else:
            # If no write_enable, assume direct mapping or pre-load
            # Try setting arr_i if it exists
            if has_signal(dut, f'arr_{i}'):
                getattr(dut, f'arr_{i}').value = clamp_to_width(val, 8)
            await RisingEdge(dut.clk)
    
    # Align clock for next operation
    await RisingEdge(dut.clk)

@cocotb.test(timeout_time=10, timeout_unit='ms')
async def test_maximal_factoring(dut):
    # Check if sequential
    is_seq = has_signal(dut, 'clk')
    
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    test_cases = [
        ("PRATTATTATTIC", 6),
        ("GGGGGGGGG", 1),
        ("PRIME", 5),
        ("BABBABABBABBA", 6),
        ("ARPARPARPARPAR", 5),
        ("ABABA", 4), # (AB)^2 A or A (BA)^2 -> weight 3? No, example says weight 4 (ABABA -> 4 chars)
        ("ABC", 3),
        ("AAAA", 1) # (A)^4
    ]
    
    passed = 0
    failed = 0
    
    for s, expected_weight in test_cases:
        s_clean = s.strip()
        cocotb.log.info(f"Testing string: '{s_clean}' (Expected: {expected_weight})")
        
        try:
            if is_seq:
                await load_string(dut, s_clean)
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                # Combinational logic (unlikely for this problem, but handled)
                # Would need to map inputs directly
                await Timer(100, units='ns')
            
            if not has_signal(dut, 'result'):
                raise TestFailure("Result signal missing")
                
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined (X or Z)")
                
            result = int(dut.result.value)
            
            if result != expected_weight:
                raise TestFailure(f"Expected weight {expected_weight}, got {result}")
                
            passed += 1
            cocotb.log.info(f"PASS: {s_clean} -> {result}")
            
            # Small delay between tests
            await Timer(1, units='us')
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {s_clean}: {e}")
            failed += 1
            if is_seq:
                await reset_dut(dut)

    if failed:
        raise TestFailure(f"{failed} out of {passed+failed} tests failed")

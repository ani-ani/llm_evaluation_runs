import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
MAX_ARRAY_LEN = 16
CLK_NS = 10
MAX_CYCLES = 1000

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

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(2): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

def pack_array(vals, bits=8):
    r = 0
    for i, v in enumerate(vals):
        r |= (clamp_to_width(v, bits) & ((1<<bits)-1)) << (i*bits)
    return r

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_query_sequence(dut):
    # Initialize clock
    clock = Clock(dut.clk, CLK_NS, units='ns')
    cocotb.start_soon(clock.start())
    
    await reset_dut(dut)
    
    test_cases = [
        {
            'a': [1, 2, 3, 1, 2, 1, 1],
            'a_len': 7,
            'queries': [
                {'i': 1, 'b': [1, 2, 3], 'exp': 7},
                {'i': 1, 'b': [1, 2], 'exp': 2},
                {'i': 2, 'b': [2, 3], 'exp': 2},
                {'i': 3, 'b': [1, 2], 'exp': 0},
                {'i': 4, 'b': [1, 2], 'exp': 4},
            ]
        },
        {
            'a': [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
            'a_len': 10,
            'queries': [
                {'i': 1, 'b': [1, 2, 3, 4, 5, 6, 7, 8, 9, 10], 'exp': 10},
                {'i': 7, 'b': [1, 2, 3, 4, 5, 6, 7, 8, 9, 10], 'exp': 4},
                {'i': 5, 'b': [1, 14, 7, 6, 5], 'exp': 3},
                {'i': 2, 'b': [6, 3, 4, 2, 7, 5], 'exp': 6},
                {'i': 1, 'b': [1], 'exp': 1},
            ]
        }
    ]
    
    total_passed = 0
    total_failed = 0
    
    for tc_idx, tc in enumerate(test_cases):
        cocotb.log.info(f"\nTest Case {tc_idx+1}")
        
        # Setup array A
        for i, val in enumerate(tc['a']):
            getattr(dut, f'arr_a_{i}').value = clamp_to_width(val, DATA_WIDTH)
        
        # Process each query
        for q_idx, q in enumerate(tc['queries']):
            cocotb.log.info(f"  Query {q_idx+1}: i={q['i']}, b={q['b']}, exp={q['exp']}")
            
            # Setup subset B (first fill all, unused positions are ignored)
            for j, val in enumerate(q['b']):
                getattr(dut, f'arr_b_{j}').value = clamp_to_width(val, DATA_WIDTH)
            
            # Configure parameters
            dut.a_len.value = tc['a_len']
            dut.q_idx.value = q_idx  # Not strictly used, but kept for interface consistency
            dut.query_i.value = q['i'] - 1  # Convert to 0-based
            dut.query_m.value = len(q['b'])
            
            # Start pulse
            await RisingEdge(dut.clk)
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            try:
                await wait_for_done(dut)
                
                # Read result
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result is undefined")
                
                result = int(dut.result.value)
                if result != q['exp']:
                    raise TestFailure(f"Expected {q['exp']}, got {result}")
                
                total_passed += 1
                cocotb.log.info(f"    PASS: result={result}")
                
            except TestFailure as e:
                cocotb.log.error(f"    FAIL: {e}")
                total_failed += 1
            
            # Reset for next query
            await reset_dut(dut)
            
            # Setup A again for next query
            for i, val in enumerate(tc['a']):
                getattr(dut, f'arr_a_{i}').value = clamp_to_width(val, DATA_WIDTH)
    
    if total_failed > 0:
        raise TestFailure(f"{total_failed} queries failed out of {total_passed + total_failed}")

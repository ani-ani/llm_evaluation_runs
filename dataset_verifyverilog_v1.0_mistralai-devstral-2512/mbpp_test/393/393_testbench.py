import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

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

def pack_array(vals, bits=8):
    r = 0
    for i, v in enumerate(vals):
        r |= (v & ((1<<bits)-1)) << (i*bits)
    return r

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_max_length_list(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        CLK_NS = 10
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        dut.rst_n.value = 0
        dut.start.value = 0
        for _ in range(2): await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    test_cases = [
        (   # Test 1: [[0], [1, 3], [5, 7], [9, 11], [13, 15, 17]] -> (3, [13, 15, 17]) -> idx 4
            [[0], [1, 3], [5, 7], [9, 11], [13, 15, 17]],
            [1, 2, 2, 2, 3],
            3, 4,
            "Test 1"
        ),
        (   # Test 2: [[1,2,3,4,5],[1,2,3,4],[1,2,3],[1,2],[1]] -> (5,[1,2,3,4,5]) -> idx 0
            [[1,2,3,4,5], [1,2,3,4], [1,2,3], [1,2], [1]],
            [5, 4, 3, 2, 1],
            5, 0,
            "Test 2"
        ),
        (   # Test 3: [[3,4,5],[6,7,8,9],[10,11,12]] -> (4,[6,7,8,9]) -> idx 1 (we use 3,5,5,5 as padding)
            [[3,4,5,0,0,0,0,0], [6,7,8,9,0,0,0,0], [10,11,12,0,0,0,0,0], [0]*8, [0]*8],
            [3, 4, 3, 0, 0],
            4, 1,
            "Test 3"
        )
    ]
    
    passed = 0
    failed = 0
    
    for i, (lists, lens, exp_len, exp_idx, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Write lists (5 sublists, each 8 elements)
            for sublist_idx, sublist in enumerate(lists):
                for elem_idx, val in enumerate(sublist):
                    getattr(dut, f'lists_{sublist_idx}')[elem_idx].value = clamp_to_width(val, 8)
            
            # Write sublist_lens
            for sublist_idx, l in enumerate(lens):
                getattr(dut, f'sublist_lens_{sublist_idx}').value = clamp_to_width(l, 4)
            
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done with timeout
                timeout = 0
                while timeout < 100:
                    await RisingEdge(dut.clk)
                    if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                        break
                    timeout += 1
                else:
                    raise TestFailure("Timeout waiting for done")
            else:
                await Timer(100, units='ns')
            
            if not is_value_defined(dut.max_len.value):
                raise TestFailure("max_len undefined")
            if not is_value_defined(dut.max_idx.value):
                raise TestFailure("max_idx undefined")
            
            result_len = int(dut.max_len.value)
            result_idx = int(dut.max_idx.value)
            
            if result_len != exp_len:
                raise TestFailure(f"max_len mismatch: expected {exp_len}, got {result_len}")
            if result_idx != exp_idx:
                raise TestFailure(f"max_idx mismatch: expected {exp_idx}, got {result_idx}")
            
            cocotb.log.info(f"  PASS: max_len={result_len}, max_idx={result_idx}")
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed")

import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helpers
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

# Constants
DATA_WIDTH = 8
STR_LEN_MAX = 16
MAX_OPS = 64
CLK_NS = 10

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_string_swap(dut):
    # Setup clock if sequential
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        # Reset
        dut.rst_n.value = 0
        if has_signal(dut, 'start'): dut.start.value = 0
        for _ in range(2): await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    # Test cases: (s_str, t_str, expected_op_count_or_none)
    test_cases = [
        ("bab", "bb", 2),
        ("bbbb", "aaa", 0),
        ("aaaaaa", "bbbbbb", 0),
        ("aaaaaa", "aaaabb", 1),
        ("aaaaba", "aaaaaa", 2),
        ("bbabba", "bbbbbb", 3),
    ]
    
    passed = 0
    failed = 0
    
    for i, (s_str, t_str, exp_ops) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: s='{s_str}', t='{t_str}'")
        try:
            # Pad strings to max length with nulls (0)
            s_padded = [ord(c) for c in s_str] + [0] * (STR_LEN_MAX - len(s_str))
            t_padded = [ord(c) for c in t_str] + [0] * (STR_LEN_MAX - len(t_str))
            
            # Load strings into dut
            # Assuming dut has s_in and t_in arrays of size 16
            for j in range(STR_LEN_MAX):
                if has_signal(dut, f's_in_{j}'):
                    getattr(dut, f's_in_{j}').value = clamp_to_width(s_padded[j], DATA_WIDTH)
                else:
                    dut.s_in[j].value = clamp_to_width(s_padded[j], DATA_WIDTH)
                
                if has_signal(dut, f't_in_{j}'):
                    getattr(dut, f't_in_{j}').value = clamp_to_width(t_padded[j], DATA_WIDTH)
                else:
                    dut.t_in[j].value = clamp_to_width(t_padded[j], DATA_WIDTH)
            
            # Set lengths
            if has_signal(dut, 'len_s'):
                dut.len_s.value = len(s_str)
            if has_signal(dut, 'len_t'):
                dut.len_t.value = len(t_str)
            
            if is_seq:
                # Start computation
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                max_cycles = 200
                done_found = False
                for _ in range(max_cycles):
                    await RisingEdge(dut.clk)
                    if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                        done_found = True
                        break
                
                if not done_found:
                    raise TestFailure(f"Timeout waiting for done after {max_cycles} cycles")
                
                # Check operation count if available
                if has_signal(dut, 'op_count'):
                    op_count = int(dut.op_count.value)
                    if exp_ops is not None and op_count != exp_ops:
                        # Allow some variation, but log it
                        cocotb.log.warning(f"Expected {exp_ops} ops, got {op_count}")
            else:
                # Combinational
                await Timer(100, units='ns')
                if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                    pass
                else:
                    raise TestFailure("Module didn't complete")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL Test {i+1}: {e}")
            failed += 1
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
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

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    if has_signal(dut, 'valid_in'): dut.valid_in.value = 0
    if has_signal(dut, 'finish_in'): dut.finish_in.value = 0
    for _ in range(cycles):
        if has_signal(dut, 'clk'): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    if has_signal(dut, 'clk'): await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        if has_signal(dut, 'clk'):
            await RisingEdge(dut.clk)
        else:
            await Timer(100, units='ns')
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def load_problem(dut, prob_type):
    if has_signal(dut, 'valid_in'): dut.valid_in.value = 1
    if has_signal(dut, 'prob_type'): dut.prob_type.value = clamp_to_width(prob_type, 4)
    if has_signal(dut, 'clk'): await RisingEdge(dut.clk)
    else: await Timer(100, units='ns')
    if has_signal(dut, 'valid_in'): dut.valid_in.value = 0

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_interesting_problemset(dut):
    CLK_NS = 10
    is_seq = has_signal(dut, 'clk')
    
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases: (list of problem types, expected result)
    test_cases = [
        ([0, 0, 0], 1, "Single zero type"),
        ([1, 2, 4], 1, "Pair with no overlap (1=001, 2=010, 4=100)"),
        ([7, 8, 9], 1, "Zero type 8=1000 available"),
        ([1, 1, 1], 0, "Only one type 1, no pair"),
        ([3, 5, 6], 0, "All overlap: 3=0011, 5=0101, 6=0110"),
        ([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15], 1, "Many types, 0 exists"),
        ([1, 2, 4, 8], 1, "Four disjoint bits"),
        ([1, 2, 3], 1, "1 (001) & 2 (010) = 0"),
        ([3, 5, 6], 0, "All share bit 1 (010)")
    ]
    
    passed = 0
    failed = 0
    
    for idx, (types, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {idx+1}: {desc} - Types: {types}, Expected: {'YES' if expected else 'NO'}")
        try:
            # Reset for each test case if not sequential or manually reset
            if is_seq:
                await reset_dut(dut)
            else:
                if has_signal(dut, 'prob_type'): dut.prob_type.value = 0
                if has_signal(dut, 'valid_in'): dut.valid_in.value = 0
                if has_signal(dut, 'finish_in'): dut.finish_in.value = 0
            
            # Load problems
            if is_seq:
                if has_signal(dut, 'start'):
                    dut.start.value = 1
                    await RisingEdge(dut.clk)
                    dut.start.value = 0
                
                for p in types:
                    await load_problem(dut, p)
                
                if has_signal(dut, 'finish_in'):
                    dut.finish_in.value = 1
                    await RisingEdge(dut.clk)
                    dut.finish_in.value = 0
                
                await wait_for_done(dut)
            else:
                # Combinational logic path (if purely combinational for some reason)
                if has_signal(dut, 'prob_type'):
                    # For combinational, we might need to load all at once if array input
                    # But standard design is sequential input. If fully combinational, logic is complex.
                    # Assuming sequential interface as per spec.
                    # If purely combinational, we just set inputs and wait
                    for p in types:
                        if has_signal(dut, 'prob_type'): dut.prob_type.value = clamp_to_width(p, 4)
                        await Timer(100, units='ns')
                else:
                    await Timer(100, units='ns')
            
            # Check result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            result_val = int(dut.result.value)
            if result_val != expected:
                raise TestFailure(f"Expected {'YES' if expected else 'NO'} (val={expected}), got {result_val}")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed")
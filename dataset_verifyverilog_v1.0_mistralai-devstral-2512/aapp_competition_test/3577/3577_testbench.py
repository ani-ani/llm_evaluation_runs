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

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def write_plants(dut, L_list, R_list):
    for i in range(len(L_list)):
        getattr(dut, f'L_arr_{i}').value = clamp_to_width(L_list[i], 8)
        getattr(dut, f'R_arr_{i}').value = clamp_to_width(R_list[i], 8)
    dut.len.value = clamp_to_width(len(L_list), 4)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_flower_count(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test case: Day 1: L=1,R=4 -> 0 flowers (no existing plants)
    # Day 2: L=3,R=7 -> intersects plant 1: L=1,R=4, H=1
    #   Stem L=3: 1<3<4? Yes (H=1>0) -> 1 flower
    #   Stem R=7: 1<7<4? No -> total 1
    # Day 3: L=1,R=6 -> check plants 1 (H=1) and 2 (H=2)
    #   Stem L=1: 1<1<4? No, 3<1<7? No -> 0
    #   Stem R=6: 1<6<4? No, 3<6<7? Yes (H=2>0) -> 1 flower
    # Day 4: L=2,R=6 -> check plants 1,2,3 (H=1,2,3)
    #   Stem L=2: 1<2<4? Yes -> 1; 3<2<7? No; 1<2<6? Yes -> total 2
    #   Stem R=6: 1<6<4? No; 3<6<7? Yes; 1<6<6? No -> total 2
    
    test_cases = [
        # (L_new, R_new, existing_L_list, existing_R_list, expected_result, desc)
        (1, 4, [], [], 0, "Day 1: no existing plants"),
        (3, 7, [1], [4], 1, "Day 2: stem L=3 intersects plant 1"),
        (1, 6, [1,3], [4,7], 1, "Day 3: stem R=6 intersects plant 2"),
        (2, 6, [1,3,1], [4,7,6], 2, "Day 4: both stems intersect")
    ]
    
    passed = failed = 0
    
    for i, (L_new, R_new, L_list, R_list, exp, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Write existing plants
            await write_plants(dut, L_list, R_list)
            
            # Write new plant
            dut.L_new.value = clamp_to_width(L_new, 8)
            dut.R_new.value = clamp_to_width(R_new, 8)
            
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(100, units='ns')
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            if result != exp:
                raise TestFailure(f"Expected {exp}, got {result}")
            
            passed += 1
            cocotb.log.info(f"  PASS: result={result}")
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed")
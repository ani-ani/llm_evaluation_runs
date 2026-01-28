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

@cocotb.test(timeout_time=1000, timeout_unit='ms')
async def test_sum_squares(dut):
    CLK_NS = 10
    MAX_CYCLES = 1000
    
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    async def reset_dut(dut, cycles=2):
        dut.rst_n.value = 0
        if has_signal(dut, 'start'):
            dut.start.value = 0
        for _ in range(cycles):
            if has_signal(dut, 'clk'):
                await RisingEdge(dut.clk)
            else:
                await Timer(10, units='ns')
        dut.rst_n.value = 1
        if has_signal(dut, 'clk'):
            await RisingEdge(dut.clk)
        else:
            await Timer(10, units='ns')
    
    async def wait_for_done(dut, max_cycles=1000):
        for _ in range(max_cycles):
            if has_signal(dut, 'clk'):
                await RisingEdge(dut.clk)
            else:
                await Timer(CLK_NS, units='ns')
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                return True
        raise TestFailure(f"Timeout after {max_cycles} cycles")
    
    async def write_array(dut, vals, width=16):
        # Handle individual elements or array syntax
        if hasattr(dut, 'arr') and not hasattr(dut.arr, '__len__'):
            # Try to write as packed or single port
            packed = 0
            for i, v in enumerate(vals):
                packed |= ((v & ((1 << width) - 1)) << (i * width))
            dut.arr.value = packed
        else:
            for i, v in enumerate(vals):
                attr_name = f'arr_{i}'
                if hasattr(dut, attr_name):
                    getattr(dut, attr_name).value = from_signed(v, width) if v < 0 else v
                elif hasattr(dut, 'arr') and i < len(getattr(dut, 'arr')):
                    dut.arr[i].value = from_signed(v, width) if v < 0 else v
                else:
                    raise TestFailure(f"Cannot find arr[{i}] port")
    
    def python_sum_squares(lst):
        result = 0
        for i, val in enumerate(lst):
            if i % 3 == 0:
                result += val * val
            elif i % 4 == 0:
                result += val * val * val
            else:
                result += val
        return result
    
    await reset_dut(dut)
    
    test_cases = [
        ([1, 2, 3], 6, "simple [1,2,3]"),
        ([1, 4, 9], 14, "[1,4,9] index 0 squares"),
        ([], 0, "empty list"),
        ([1, 1, 1, 1, 1, 1, 1, 1, 1], 9, "nine ones"),
        ([-1, -1, -1, -1, -1, -1, -1, -1, -1], -3, "nine negative ones"),
        ([0], 0, "single zero"),
        ([-1, -5, 2, -1, -5], -126, "negative example"),
        ([-56, -99, 1, 0, -2], 3030, "mixed values small array"),
        ([-1, 0, 0, 0, 0, 0, 0, 0, -1], 0, "edge zeros with negs"),
        ([-16, -9, -2, 36, 36, 26, -20, 25, -40, 20, -4, 12, -26, 35, 37], -14196, "large negative result"),
        ([-1, -3, 17, -1, -15, 13, -1, 14, -14, -12, -5, 14, -14, 6, 13, 11, 16, 16, 4, 10], -1448, "full 20 elements")
    ]
    
    passed = 0
    failed = 0
    
    for i, (test_arr, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc} with len={len(test_arr)}")
        
        try:
            if has_signal(dut, 'arr'):
                await write_array(dut, test_arr)
            else:
                raise TestFailure("Array input not found")
            
            if has_signal(dut, 'len'):
                dut.len.value = len(test_arr)
            else:
                dut.len.value = len(test_arr) if hasattr(dut, 'len') else None
            
            if has_signal(dut, 'start'):
                dut.start.value = 1
                if has_signal(dut, 'clk'):
                    await RisingEdge(dut.clk)
                else:
                    await Timer(CLK_NS, units='ns')
                dut.start.value = 0
            else:
                # Combinational or external start
                pass
            
            if has_signal(dut, 'done') or has_signal(dut, 'busy') or has_signal(dut, 'state'):
                await wait_for_done(dut, MAX_CYCLES)
            else:
                await Timer(500, units='ns')
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            raw_result = int(dut.result.value)
            result = to_signed(raw_result, 16)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"Test {i+1} FAIL: {e}")
            failed += 1
        
        await reset_dut(dut)
    
    if failed > 0:
        raise TestFailure(f"{failed} out of {passed + failed} tests failed")
import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
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

# Array access
def write_array(dut, name, values, width):
    for i, v in enumerate(values):
        arr_elem = getattr(dut, name)
        if hasattr(arr_elem, '__getitem__'):
            arr_elem[i].value = clamp_to_width(v, width)
        else:
            # Packed array handling
            pass

def read_array(dut, name, size, width):
    vals = []
    for i in range(size):
        arr_elem = getattr(dut, name)
        if hasattr(arr_elem, '__getitem__'):
            v = int(arr_elem[i].value)
        else:
            v = 0
        vals.append(v)
    return vals

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_paint_the_numbers(dut):
    # Parameters
    CLK_NS = 10
    MAX_CYCLES = 10000
    DATA_WIDTH = 7  # Values 1-100
    N_WIDTH = 4    # n ≤ 16
    RESULT_WIDTH = 5
    
    # Clock and reset
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        dut.rst_n.value = 0
        if has_signal(dut, 'start'): dut.start.value = 0
        for _ in range(2):
            await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    else:
        # Combinational
        await Timer(100, units='ns')
    
    # Test cases (scaled to n≤16)
    test_cases = [
        ([10, 2, 3, 5, 4, 2], 3),  # n=6
        ([100, 100, 100, 100], 1), # n=4
        ([7, 6, 5, 4, 3, 2, 2, 3], 4), # n=8
        ([1], 1),
        ([100], 1),
        ([2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53], 16), # All primes -> 16 colors
        ([2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22, 24, 26, 28, 30, 32], 1),   # All multiples of 2 -> 1 color
        ([1, 1, 1, 1], 1), # 1 divides everything
        ([2, 1, 2, 2], 1), # Sorts to 1,2,2,2 -> 1 color
        ([3, 5, 7, 11], 4), # Primes -> 4 colors
        ([6, 2, 3, 4, 12], 2), # Example: 6,3,12 and 2,4 -> 2 colors (but note sorted: 2,3,4,6,12 -> colors: 2->marks 4,6,12; 3->marks 6,12; 4->marks 12; etc. Wait, algorithm: smallest unmarked is 2 -> color 1, marks multiples (4,6,12). Next unmarked 3 -> color 2, marks multiples (6,12). Next unmarked 4? No, marked. 6? Marked. 12? Marked. So 2 colors. Correct.)
    ]
    
    for idx, (input_vals, expected) in enumerate(test_cases):
        # Scale input to n≤16
        if len(input_vals) > 16:
            input_vals = input_vals[:16]
        n = len(input_vals)
        
        cocotb.log.info(f"Test {idx+1}: n={n}, values={input_vals}, expected={expected}")
        
        try:
            # Reset for each test if needed
            if has_signal(dut, 'rst_n') and idx > 0:
                dut.rst_n.value = 0
                await RisingEdge(dut.clk)
                dut.rst_n.value = 1
                await RisingEdge(dut.clk)
            
            # Load array
            if has_signal(dut, 'wr_en') and has_signal(dut, 'addr_wr') and has_signal(dut, 'a_i'):
                for i in range(n):
                    dut.wr_en.value = 1
                    dut.addr_wr.value = i
                    dut.a_i.value = clamp_to_width(input_vals[i], DATA_WIDTH)
                    await RisingEdge(dut.clk)
                dut.wr_en.value = 0
            else:
                # Direct array assignment for simple test
                write_array(dut, 'arr', input_vals, DATA_WIDTH)
            
            # Set n if signal exists
            if has_signal(dut, 'n'):
                dut.n.value = clamp_to_width(n, N_WIDTH)
            
            # Start
            if has_signal(dut, 'start'):
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                done_cycles = 0
                while done_cycles < MAX_CYCLES:
                    await RisingEdge(dut.clk)
                    if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                        break
                    done_cycles += 1
                else:
                    raise TestFailure(f"Timeout after {MAX_CYCLES} cycles")
            
            # Read result
            if has_signal(dut, 'result'):
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result undefined")
                result = int(dut.result.value)
            else:
                # For combinational, maybe result is directly output
                await Timer(100, units='ns')
                if has_signal(dut, 'result'):
                    result = int(dut.result.value)
                else:
                    raise TestFailure("Result signal not found")
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
                
        except TestFailure as e:
            cocotb.log.error(f"Test {idx+1} FAIL: {e}")
            raise

    cocotb.log.info("All tests passed!")

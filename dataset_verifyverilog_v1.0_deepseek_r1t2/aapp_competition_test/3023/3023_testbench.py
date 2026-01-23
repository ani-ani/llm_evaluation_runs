import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 16
COEFF_WIDTH = 32
N_MAX = 8
M_MAX = 4
CLK_PERIOD_NS = 10
MAX_CYCLES = 2000

def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_cake_divider(dut):
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    await reset_dut(dut)
    
    test_cases = [
        (4, 2, 3, [0, 1, -1, 0], [1, 0, 0, -1], [-1, 2], [1, 1], [0, 0], 1, "Example 1"),
        (4, 3, 3, [0, 1, -1, 0], [1, 2, 2, -1], [-1, -1, 0], [1, -1, -1], [-2, 2, 0], 0, "Example 2"),
        (3, 2, 3, [2, 0, -1], [1, 0, -2], [1, 3], [1, 6], [-2, 12], 1, "Example 3"),
        (3, 1, 2, [0, -1, 1], [0, 1, -1], [-2], [2], [1], 0, "Example 4"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n, m, r, x_list, y_list, a_list, b_list, c_list, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        
        try:
            dut.n.value = n
            dut.m.value = m
            dut.r.value = r
            
            for j in range(N_MAX):
                if j < n:
                    x_val = x_list[j]
                    y_val = y_list[j]
                    if x_val < 0:
                        x_val += (1 << DATA_WIDTH)
                    if y_val < 0:
                        y_val += (1 << DATA_WIDTH)
                    
                    if has_signal(dut, f'x_candles_{j}'):
                        getattr(dut, f'x_candles_{j}').value = x_val
                        getattr(dut, f'y_candles_{j}').value = y_val
                    else:
                        dut.x_candles[j].value = x_val
                        dut.y_candles[j].value = y_val
                else:
                    if has_signal(dut, f'x_candles_{j}'):
                        getattr(dut, f'x_candles_{j}').value = 0
                        getattr(dut, f'y_candles_{j}').value = 0
                    else:
                        dut.x_candles[j].value = 0
                        dut.y_candles[j].value = 0
            
            for j in range(M_MAX):
                if j < m:
                    a_val = a_list[j]
                    b_val = b_list[j]
                    c_val = c_list[j]
                    if a_val < 0:
                        a_val += (1 << COEFF_WIDTH)
                    if b_val < 0:
                        b_val += (1 << COEFF_WIDTH)
                    if c_val < 0:
                        c_val += (1 << COEFF_WIDTH)
                    
                    if has_signal(dut, f'a_lines_{j}'):
                        getattr(dut, f'a_lines_{j}').value = a_val
                        getattr(dut, f'b_lines_{j}').value = b_val
                        getattr(dut, f'c_lines_{j}').value = c_val
                    else:
                        dut.a_lines[j].value = a_val
                        dut.b_lines[j].value = b_val
                        dut.c_lines[j].value = c_val
                else:
                    if has_signal(dut, f'a_lines_{j}'):
                        getattr(dut, f'a_lines_{j}').value = 0
                        getattr(dut, f'b_lines_{j}').value = 0
                        getattr(dut, f'c_lines_{j}').value = 0
                    else:
                        dut.a_lines[j].value = 0
                        dut.b_lines[j].value = 0
                        dut.c_lines[j].value = 0
            
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            await wait_for_done(dut)
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result = int(dut.result.value)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")

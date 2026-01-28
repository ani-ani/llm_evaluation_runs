import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

MAX_N = 8
CLK_PERIOD_NS = 10
TIMEOUT_CYCLES = 10000

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

def compute_mask(n, i, l_i, r_i):
    mask = 0
    start = (i - l_i) % n
    end = (i + r_i) % n
    if start <= end:
        for j in range(start, end + 1):
            mask |= (1 << j)
    else:
        for j in range(start, n):
            mask |= (1 << j)
        for j in range(0, end + 1):
            mask |= (1 << j)
    return mask

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_halloween_costumes(dut):
    is_sequential = has_signal(dut, 'clk')
    if is_sequential:
        cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
        dut.rst_n.value = 0
        if has_signal(dut, 'start'):
            dut.start.value = 0
        for _ in range(2):
            await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    test_cases = [
        (5, [(1,0,0), (1,0,1), (3,0,1), (3,0,0), (3,0,1)], 0),
        (5, [(3,1,1), (0,3,1), (1,3,1), (1,2,1), (0,4,1)], 4),
    ]
    
    passed = 0
    failed = 0
    
    for test_i, (n, constraints, expected) in enumerate(test_cases):
        dut._log.info(f"Test {test_i+1}: n={n}, expected={expected}")
        try:
            masks = []
            xs = []
            for i, (l_i, r_i, x_i) in enumerate(constraints):
                mask = compute_mask(n, i, l_i, r_i)
                masks.append(mask)
                xs.append(x_i)
            
            if has_signal(dut, 'n'):
                dut.n.value = n
            else:
                raise TestFailure("Signal 'n' not found")
            
            for i in range(MAX_N):
                if i < len(masks):
                    getattr(dut, f'mask_{i}').value = masks[i]
                    getattr(dut, f'x_{i}').value = xs[i]
                else:
                    if has_signal(dut, f'mask_{i}'):
                        getattr(dut, f'mask_{i}').value = 0
                    if has_signal(dut, f'x_{i}'):
                        getattr(dut, f'x_{i}').value = 0
            
            if is_sequential:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
            else:
                await Timer(100, units='ns')
            
            if is_sequential and has_signal(dut, 'done'):
                for _ in range(TIMEOUT_CYCLES):
                    await RisingEdge(dut.clk)
                    if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                        break
                else:
                    raise TestFailure("Timeout waiting for done")
            else:
                await Timer(200, units='ns')
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined")
            
            result = int(dut.result.value)
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            dut._log.info(f"  PASS: result={result}")
            passed += 1
        except TestFailure as e:
            dut._log.error(f"  FAIL: {e}")
            failed += 1
    
    dut._log.info(f"Results: {passed}/{passed+failed} passed")
    if failed > 0:
        raise TestFailure(f"{failed} test(s) failed")
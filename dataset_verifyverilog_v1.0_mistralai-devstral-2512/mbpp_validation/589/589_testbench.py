import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH, MAX_SQUARES, CLK_NS, MAX_CYCLES = 8, 16, 10, 300

# Helper functions
def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except ValueError:
        return default

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

async def wait_for_done(dut, max_cycles=300):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def write_inputs(dut, a, b):
    dut.a.value = clamp_to_width(a, DATA_WIDTH)
    dut.b.value = clamp_to_width(b, DATA_WIDTH)

async def read_result(dut):
    result = []
    if has_signal(dut, 'count'):
        count = int(dut.count.value)
        for i in range(MAX_SQUARES):
            sig_name = f'result_{i}' if not hasattr(dut.result, '__getitem__') else None
            if sig_name and has_signal(dut, sig_name):
                val = int(getattr(dut, sig_name).value)
                if i < count:
                    result.append(val)
            elif hasattr(dut.result, '__getitem__'):
                try:
                    val = int(dut.result[i].value)
                    if i < count:
                        result.append(val)
                except:
                    break
            else:
                result.append(int(dut.result.value) if i == 0 else 0)
        return sorted(result)
    else:
        return []

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_perfect_squares(dut):
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational design
        await Timer(100, units='ns')
    
    # Test cases: (a, b, expected_squares)
    test_cases = [
        (1, 30, [1, 4, 9, 16, 25]),
        (50, 100, [64, 81, 100]),
        (100, 200, [100, 121, 144, 169, 196]),
        (0, 16, [0, 1, 4, 9, 16]),
        (200, 255, [225, 256]) if 256 <= 255 else [225],  # 256 > 255, adjust
        (150, 255, [169, 196, 225]),
        (5, 5, []),
    ]
    
    passed = 0
    failed = 0
    
    for i, (a, b, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: a={a}, b={b}")
        try:
            await write_inputs(dut, a, b)
            
            if has_signal(dut, 'start'):
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(100, units='ns')
            
            result = await read_result(dut)
            
            # Adjust expected for edge case where 256 appears
            expected = [x for x in expected if x <= 255]
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            cocotb.log.info(f"  PASSED: {result}")
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} out of {passed + failed} tests failed")
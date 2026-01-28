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

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=10000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=10, timeout_unit="ms")
async def test_largest_divisor(dut):
    # Test cases: (n, expected_result)
    test_cases = [
        (0, 0),
        (1, 0),
        (2, 1),
        (3, 1),
        (7, 1),
        (10, 5),
        (15, 5),
        (17, 1),
        (49, 7),
        (100, 50),
        (1024, 512),
        (65535, 32767),
    ]
    
    is_seq = has_signal(dut, 'clk') and has_signal(dut, 'rst_n')
    
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    
    passed = 0
    failed = 0
    
    for i, (n_val, exp_val) in enumerate(test_cases):
        cocotb.log.info(f"Test case {i+1}: n={n_val}, expecting {exp_val}")
        
        try:
            # Set input n (16-bit)
            dut.n.value = clamp_to_width(n_val, 16)
            
            if is_seq:
                # Start the computation
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                # Wait for done signal
                await wait_for_done(dut, max_cycles=70000)
            else:
                # Combinational: wait for propagation
                await Timer(10, units='ns')
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            result = int(dut.result.value)
            
            if result != exp_val:
                raise TestFailure(f"For n={n_val}, expected {exp_val}, got {result}")
            
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: Test case {i+1} - {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} test(s) failed out of {passed + failed}")
    
    cocotb.log.info(f"All {passed} tests passed")
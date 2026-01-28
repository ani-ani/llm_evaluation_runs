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

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        if has_signal(dut, 'clk'):
            await RisingEdge(dut.clk)
        else:
            await Timer(10, units='ns')
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    if has_signal(dut, 'clk'):
        for _ in range(cycles):
            await RisingEdge(dut.clk)
    else:
        await Timer(cycles * 10, units='ns')
    dut.rst_n.value = 1
    if has_signal(dut, 'clk'):
        await RisingEdge(dut.clk)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_bit_length(dut):
    # Setup clock if sequential
    is_seq = has_signal(dut, 'clk')
    CLK_NS = 10
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational - just set inputs
        pass
    
    # Test cases: (n, expected_result)
    test_cases = [
        (6, 3),
        (2, 2),
        (1, 1),
        (3, 2),
        (7, 3),
        (8, 4),
        (15, 4),
        (16, 5),
        (31, 5),
        (32, 6),
        (1023, 10),
        (1024, 11),
        (1025, 11),
        (1000000000, 30),  # 10^9
        (536870911, 29),   # 2^29 - 1
        (536870912, 30),   # 2^29
        (536870913, 30),   # 2^29 + 1
    ]
    
    passed = 0
    failed = 0
    
    for n, expected in test_cases:
        cocotb.log.info(f"Testing n={n}, expected={expected}")
        try:
            # Set input
            if has_signal(dut, 'n'):
                dut.n.value = clamp_to_width(n, 30)
            elif has_signal(dut, 'n_0'):  # Array notation
                for i in range(30):
                    val = (n >> i) & 1
                    getattr(dut, f'n_{i}').value = val
            else:
                raise TestFailure("Input signal 'n' not found")
            
            # Start pulse
            if is_seq:
                if has_signal(dut, 'start'):
                    dut.start.value = 1
                    await RisingEdge(dut.clk)
                    dut.start.value = 0
                else:
                    # Maybe start is not needed, just wait for result
                    await RisingEdge(dut.clk)
                
                # Wait for done
                await wait_for_done(dut)
                
                # Read result
                result_signal = dut.result
                if not is_value_defined(result_signal.value):
                    raise TestFailure("Result signal undefined")
                result = int(result_signal.value)
            else:
                # Combinational, just read after some delay
                await Timer(100, units='ns')
                result = int(dut.result.value)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            cocotb.log.info(f"PASS: n={n} -> {result}")
                
        except TestFailure as e:
            cocotb.log.error(f"FAIL: n={n} - {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed")
    
    cocotb.log.info(f"All tests passed: {passed}/{len(test_cases)}")
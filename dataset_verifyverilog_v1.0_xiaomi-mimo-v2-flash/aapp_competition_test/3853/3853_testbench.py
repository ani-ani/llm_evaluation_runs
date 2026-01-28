import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 32
CLK_NS = 10
MAX_CYCLES = 5000

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

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    if has_signal(dut, 'in_valid'):
        dut.in_valid.value = 0
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

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_magic_boxes(dut):
    # Setup Clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases: list of (list of (k, a), expected_p)
    test_cases = [
        ([(0, 3), (1, 5)], 3),  # Example 1
        ([(0, 4)], 1),          # Example 2
        ([(1, 10), (2, 2)], 3), # Example 3
        ([(0, 1)], 1),
        ([(1, 16777216), (16, 1)], 17), # Propagating carry across gaps
        ([(0, 268435456)], 14), # Large count
    ]
    
    passed = 0
    failed = 0
    
    for i, (inputs, expected_p) in enumerate(test_cases):
        cocotb.log.info(f"Running Test Case {i+1}: {inputs} -> Expect {expected_p}")
        
        # Send inputs
        for k, a in inputs:
            # Wait for ready if any (assuming simple acceptance for now or flow control)
            # For this spec, we drive inputs and valid high for 1 cycle
            dut.in_k.value = clamp_to_width(k, 32)
            dut.in_a.value = clamp_to_width(a, 32)
            dut.in_valid.value = 1
            await RisingEdge(dut.clk)
            dut.in_valid.value = 0
            # Small delay if needed, but typically back-to-back is fine if internal logic is fast enough
            # Or wait for ready signal if module has one. Assuming no ready for simplicity of spec, 
            # testbench just pulses valid. If module requires bubbles, this needs adjustment.
            # The prompt implies a stream. Let's assume the module can accept every cycle or we add a small delay.
            await Timer(1, units='ns')
        
        # Wait for done
        try:
            await wait_for_done(dut)
            result = int(dut.result_p.value)
            if result != expected_p:
                raise TestFailure(f"Expected {expected_p}, got {result}")
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL Case {i+1}: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed")
    
    cocotb.log.info(f"All {passed} tests passed!")
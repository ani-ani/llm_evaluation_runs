import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration
DATA_WIDTH = 4
RESULT_WIDTH = 16
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

# Helper functions
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

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def start_computation(dut):
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_vault_security(dut):
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases: (A, B, L, (insecure, secure, super_secure))
    test_cases = [
        (1, 1, 3, (2, 2, 5)),
        (2, 3, 4, (0, 16, 8)),
        (3, 3, 3, (2, 12, 6)),
    ]
    
    for i, (A, B, L, expected) in enumerate(test_cases):
        insecure_exp, secure_exp, super_exp = expected
        cocotb.log.info(f"Test {i+1}: A={A}, B={B}, L={L}")
        
        # Set inputs
        dut.A.value = clamp_to_width(A, DATA_WIDTH)
        dut.B.value = clamp_to_width(B, DATA_WIDTH)
        dut.L.value = clamp_to_width(L, DATA_WIDTH)
        
        await start_computation(dut)
        await wait_for_done(dut)
        
        # Read outputs
        if not all([is_value_defined(dut.insecure.value),
                   is_value_defined(dut.secure.value),
                   is_value_defined(dut.super_secure.value)]):
            raise TestFailure("Outputs are undefined (X/Z)")
        
        insecure = int(dut.insecure.value)
        secure = int(dut.secure.value)
        super_secure = int(dut.super_secure.value)
        
        cocotb.log.info(f"  Result: insecure={insecure}, secure={secure}, super={super_secure}")
        
        if insecure != insecure_exp or secure != secure_exp or super_secure != super_exp:
            raise TestFailure(
                f"Test {i+1} failed: expected ({insecure_exp}, {secure_exp}, {super_exp}), "
                f"got ({insecure}, {secure}, {super_secure})"
            )
        
        cocotb.log.info(f"  PASS")
    
    cocotb.log.info("All tests passed!")
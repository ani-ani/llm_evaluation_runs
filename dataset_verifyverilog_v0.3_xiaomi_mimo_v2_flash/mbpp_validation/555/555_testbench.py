import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration
N_WIDTH = 6
RESULT_WIDTH = 32
CLK_PERIOD_NS = 10
MAX_CYCLES = 100

def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

async def reset_dut(dut):
    dut.rst_n.value = 0
    if hasattr(dut, 'start'):
        dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def start_computation(dut):
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_difference_calculator(dut):
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    await reset_dut(dut)
    
    test_cases = [
        (3, 30),
        (5, 210),
        (2, 6),
    ]
    
    passed = 0
    failed = 0
    
    for n, expected in test_cases:
        dut.n.value = clamp_to_width(n, N_WIDTH)
        await start_computation(dut)
        
        for _ in range(MAX_CYCLES):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                result = int(dut.result.value)
                if result == expected:
                    passed += 1
                else:
                    cocotb.log.error(f"Test n={n} failed: expected {expected}, got {result}")
                    failed += 1
                break
        else:
            cocotb.log.error(f"Timeout for n={n}")
            failed += 1
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
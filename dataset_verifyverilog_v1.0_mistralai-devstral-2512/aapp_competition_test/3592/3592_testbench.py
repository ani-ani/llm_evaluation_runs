import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

DATA_WIDTH = 32
FRAC_BITS = 16
CLK_NS = 10
MAX_CYCLES = 2000

def float_to_fixed(f, frac=FRAC_BITS):
    return int(round(f * (1 << frac)))

def fixed_to_float(v, frac=FRAC_BITS):
    return v / (1 << frac)

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_profit_solver(dut):
    # Check for clock
    if not has_signal(dut, 'clk'):
        raise TestFailure("Missing clock signal 'clk'")
    
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases: (pt, p1, p2, expected [(x, y), ...])
    test_cases = [
        (725.85, 1.71, 2.38, [(199, 162)]),
        (100.00, 20.00, 10.00, [(0, 10), (1, 8), (2, 6), (3, 4), (4, 2), (5, 0)]),
        (10.00, 3.00, 2.00, [(0, 5), (2, 2)]),
        (50.00, 15.00, 10.00, [(0, 5), (2, 2)]),
        (1.00, 1.50, 2.50, []),
        (0.00, 1.00, 2.00, [(0, 0)]),
        (10000.00, 0.01, 0.02, []), # Too large for iteration
    ]

    for i, (pt_f, p1_f, p2_f, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: pt={pt_f}, p1={p1_f}, p2={p2_f}")
        
        # Convert to fixed-point
        pt = float_to_fixed(pt_f)
        p1 = float_to_fixed(p1_f)
        p2 = float_to_fixed(p2_f)
        
        # Clamp to width (simulating 32-bit input)
        pt &= 0xFFFFFFFF
        p1 &= 0xFFFFFFFF
        p2 &= 0xFFFFFFFF
        
        # Check if p1 or p2 are effectively zero (should handle as error/no solution)
        # In this spec, 0 < p1, p2, but float conversion might yield 0. Assume valid inputs.
        if p1 == 0 or p2 == 0:
            cocotb.log.info("Skipping test with zero profit per item")
            continue

        dut.pt.value = pt
        dut.p1.value = p1
        dut.p2.value = p2
        
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Collect results
        results = []
        max_output_cycles = 200
        for _ in range(max_output_cycles):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.result_valid.value) and int(dut.result_valid.value) == 1:
                x = int(dut.num_pitas.value)
                y = int(dut.num_pizzas.value)
                results.append((x, y))
                cocotb.log.info(f"  Found: {x} pitas, {y} pizzas")
            
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                break
        else:
            raise TestFailure(f"Test {i+1}: Did not assert done within {max_output_cycles} cycles")
        
        # Verify results
        # Sort expected results by x
        expected.sort(key=lambda pair: pair[0])
        
        if len(results) != len(expected):
            raise TestFailure(f"Test {i+1}: Expected {len(expected)} solutions, got {len(results)}. Results: {results}")
        
        for (exp_x, exp_y), (res_x, res_y) in zip(expected, results):
            if (exp_x, exp_y) != (res_x, res_y):
                raise TestFailure(f"Test {i+1}: Mismatch. Expected ({exp_x}, {exp_y}), got ({res_x}, {res_y})")
        
        cocotb.log.info(f"Test {i+1} PASSED")

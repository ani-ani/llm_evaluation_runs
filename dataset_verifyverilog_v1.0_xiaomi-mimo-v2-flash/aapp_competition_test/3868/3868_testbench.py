import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

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

def to_signed(val, bits):
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    if val < 0:
        return val + (1 << bits)
    return val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

# Testbench logic
DATA_WIDTH = 16
MAX_DAYS = 256
MAX_FLIGHTS = 32
CLK_NS = 10
MAX_CYCLES = 10000

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    if has_signal(dut, 'flight_valid'):
        dut.flight_valid.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=10000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if has_signal(dut, 'done') and is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_flights(dut):
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)

    # Test Case 1: From problem statement (scaled down)
    # Original: n=2, m=6, k=5
    # We simulate n=2 (cities 1,2)
    # Flights (day, from, to, cost):
    # 1 1 0 5000
    # 3 2 0 5500
    # 2 2 0 6000
    # 15 0 2 9000
    # 9 0 1 7000
    # 8 0 2 6500
    
    test_flights_data = [
        (1, 1, 0, 5000),
        (3, 2, 0, 5500),
        (2, 2, 0, 6000),
        (15, 0, 2, 9000),
        (9, 0, 1, 7000),
        (8, 0, 2, 6500)
    ]
    k_val = 5
    expected_cost = 24500

    # Start processing
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Feed flights
    # In the simplified HDL spec, we feed flights sequentially while 'start' or 'valid' is high
    # For this test, we assume the HDL has a FIFO-like input or we drive it cycle by cycle
    # Let's assume we drive 'flight_valid' high for each flight over multiple cycles
    
    for day, fro, to, cost in test_flights_data:
        dut.flight_day.value = day
        dut.flight_from.value = fro
        dut.flight_to.value = to
        dut.flight_cost.value = clamp_to_width(cost, 16)
        dut.flight_valid.value = 1
        await RisingEdge(dut.clk)
    
    dut.flight_valid.value = 0
    dut.k_duration.value = k_val

    # Wait for done
    await wait_for_done(dut)

    # Check result
    if not is_value_defined(dut.min_cost.value):
        raise TestFailure("Result undefined")
    
    result = int(dut.min_cost.value)
    if result != expected_cost:
        raise TestFailure(f"Expected {expected_cost}, got {result}")

    cocotb.log.info(f"Test passed! Cost: {result}")

    # Test Case 2: Impossible case
    await reset_dut(dut)
    # Input:
    # 2 4 5
    # 1 2 0 5000
    # 2 1 0 4500
    # 2 1 0 3000
    # 8 0 1 6000
    # City 2 has no return flight!
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    impossible_flights = [
        (1, 2, 0, 5000),
        (2, 1, 0, 4500),
        (2, 1, 0, 3000),
        (8, 0, 1, 6000)
    ]
    
    for day, fro, to, cost in impossible_flights:
        dut.flight_day.value = day
        dut.flight_from.value = fro
        dut.flight_to.value = to
        dut.flight_cost.value = clamp_to_width(cost, 16)
        dut.flight_valid.value = 1
        await RisingEdge(dut.clk)
    
    dut.flight_valid.value = 0
    dut.k_duration.value = 5

    await wait_for_done(dut)

    if not is_value_defined(dut.impossible.value):
        raise TestFailure("Impossible signal undefined")
    
    if int(dut.impossible.value) != 1:
        raise TestFailure(f"Expected impossible=1, got {int(dut.impossible.value)}")
        
    cocotb.log.info("Test passed! Identified as impossible.")
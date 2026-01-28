import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Constants
DATA_WIDTH = 16
CLK_NS = 10
MAX_CYCLES = 20000  # 1024 years * ~16 ops + overhead

# Helpers
def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def clamp_to_width(v, bits):
    max_val = (1 << bits) - 1
    if v < 0: return 0
    if v > max_val: return max_val
    return v

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# Python Reference Implementation
def calculate_max_pop(species):
    # species: list of tuples (Y, I, S, B)
    max_pop = 0
    # Check years 0 to 1023
    for year in range(1024):
        current_total = 0
        for Y, I, S, B in species:
            if year < B:
                pop = 0
            else:
                t = year - B
                if t <= Y:
                    pop = S + t * I
                else:
                    # Decreasing phase
                    peak_pop = S + Y * I
                    decrease = (t - Y) * I
                    pop = peak_pop - decrease
                    if pop < 0:
                        pop = 0
            current_total += pop
        if current_total > max_pop:
            max_pop = current_total
    return max_pop

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_jack_forest(dut):
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational logic (should be fast)
        await Timer(10, units='ns')

    test_cases = [
        [(10, 10, 0, 5)],  # Case 1: N=1
        [(5, 10, 0, 4), (10, 10, 10, 1), (5, 5, 0, 0)]  # Case 2: N=3
    ]

    expected_outputs = [100, 145]

    passed = 0
    failed = 0

    for idx, (species_data) in enumerate(test_cases):
        cocotb.log.info(f"Test Case {idx + 1}: {species_data}")
        
        # Calculate expected result in Python
        expected = calculate_max_pop(species_data)
        cocotb.log.info(f"Expected Result: {expected}")
        
        try:
            if has_signal(dut, 'clk'):
                # Sequential implementation
                n = len(species_data)
                dut.species_count.value = n
                
                # Feed data
                for (Y, I, S, B) in species_data:
                    dut.Y_in.value = Y
                    dut.I_in.value = I
                    dut.S_in.value = S
                    dut.B_in.value = B
                    dut.start.value = 1
                    await RisingEdge(dut.clk)
                    dut.start.value = 0
                
                # Wait for done
                await wait_for_done(dut)
                
                result = int(dut.result.value)
            else:
                # Combinational implementation (assumes all inputs registered or immediate)
                # In a pure combinational design, we feed all data and check output
                # For this test, we will assume sequential if clock present, else comb
                raise TestFailure("Sequential test required for this design")

            if result != expected:
                raise TestFailure(f"Mismatch: Expected {expected}, Got {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1

    if failed:
        raise TestFailure(f"{failed} tests failed")

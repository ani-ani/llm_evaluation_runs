import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# ============================================================================
# CONFIGURATION
# ============================================================================
N = 2                     # Number of cities
MAX_FLIGHTS = 8          # Maximum number of flights
MAX_DAY = 16             # Maximum day
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000
DATA_WIDTH = 16
RESULT_WIDTH = 20

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    """Safely convert cocotb value to int, returning default if X/Z."""
    try:
        return int(value)
    except ValueError:
        return default

def has_signal(dut, name):
    """Check if DUT has a signal with given name."""
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    """Clamp value to fit within specified bit width (unsigned)."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

def pack_flight(day, from_city, to_city, cost, valid=1):
    """Pack flight data into 28-bit value."""
    # Format: valid[0], day[4:0], from[2:0], to[2:0], cost[15:0]
    # But in Verilog, we defined: flights[i*28 + 27] = valid
    # So for flight packed value: {valid, day, from, to, cost}
    # But since we assign to a vector, we need to create the value in MSB order for each flight
    # Actually, in the unpacking, we defined:
    #   flights[i*28 + 27] = valid
    #   flights[i*28 + 26: i*28 + 22] = day
    #   etc.
    # So when we pack, for a flight at index i, we set:
    #   value = (valid << 27) | (day << 22) | (from_city << 19) | (to_city << 16) | cost
    return (valid << 27) | (day << 22) | (from_city << 19) | (to_city << 16) | cost

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_min_cost_gather(dut):
    """Test the min_cost_gather module with example test cases."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.flights.value = 0
    for _ in range(3):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Define test cases based on scaled problem examples
    # Format: (flights, k, expected_cost, description)
    # Flights: list of tuples (day, from_city, to_city, cost)
    test_cases = [
        # Example 1: n=2, k=5, expected cost=24500
        (
            [
                (1, 1, 0, 5000),
                (3, 2, 0, 5500),
                (2, 2, 0, 6000),
                (15, 0, 2, 9000),
                (9, 0, 1, 7000),
                (8, 0, 2, 6500),
            ],
            5,
            24500,
            "Example 1 from problem"
        ),
        # Example 2: n=2, k=5, expected -1
        (
            [
                (1, 2, 0, 5000),
                (2, 1, 0, 4500),
                (2, 1, 0, 3000),
                (8, 0, 1, 6000),
            ],
            5,
            -1,
            "Example 2 from problem"
        ),
        # Additional test case with small costs
        (
            [
                (1, 1, 0, 1),
                (2, 2, 0, 10),
                (8, 0, 1, 100),
                (9, 0, 2, 1000),
            ],
            1,
            111,
            "Small costs"
        ),
    ]
    
    for test_idx, (flights, k, expected, desc) in enumerate(test_cases):
        dut._log.info(f"\nTest {test_idx+1}: {desc}")
        dut._log.info(f"Flights: {flights}")
        dut._log.info(f"k = {k}, Expected = {expected}")
        
        # Pack flight data into flights vector
        flights_packed = 0
        for i, (day, from_city, to_city, cost) in enumerate(flights):
            if i < MAX_FLIGHTS:
                # Ensure values fit in bit widths
                day_val = clamp_to_width(day, 5)
                from_val = clamp_to_width(from_city, 3)
                to_val = clamp_to_width(to_city, 3)
                cost_val = clamp_to_width(cost, 16)
                flight_val = pack_flight(day_val, from_val, to_val, cost_val, valid=1)
                flights_packed |= flight_val << (28 * i)
        # Mark unused flights as invalid
        for i in range(len(flights), MAX_FLIGHTS):
            flights_packed |= 0 << (28 * i)  # valid=0
        
        # Set inputs
        dut.flights.value = flights_packed
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        cycles = 0
        while not (is_value_defined(dut.done.value) and int(dut.done.value) == 1):
            await RisingEdge(dut.clk)
            cycles += 1
            if cycles > MAX_CYCLES:
                raise TestFailure(f"Timeout waiting for done after {MAX_CYCLES} cycles")
        
        # Read result
        if not is_value_defined(dut.min_cost.value):
            raise TestFailure("min_cost is undefined (X/Z)")
        
        result = int(dut.min_cost.value)
        
        # Check if result is INF (0xFFFFF) for no solution
        INF = (1 << 20) - 1  # 20-bit INF
        if expected == -1:
            if result != INF:
                raise TestFailure(f"Test {test_idx+1} failed: expected no solution (INF), got {result}")
        else:
            if result == INF:
                raise TestFailure(f"Test {test_idx+1} failed: expected {expected}, got INF")
            if result != expected:
                raise TestFailure(f"Test {test_idx+1} failed: expected {expected}, got {result}")
        
        dut._log.info(f"Test {test_idx+1} passed: result = {result}")
        
        # Reset for next test
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    dut._log.info("\nAll tests passed!")

import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# MANDATORY HELPER FUNCTIONS
# ============================================================================
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    try:
        return int(value)
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

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    if value < 0:
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# ============================================================================
# ARRAY HELPERS
# ============================================================================
async def write_array(dut, array_name, values, element_width):
    arr = getattr(dut, array_name)
    for i, val in enumerate(values):
        arr[i].value = clamp_to_width(val, element_width)

async def read_array(dut, array_name, size):
    results = []
    arr = getattr(dut, array_name)
    for i in range(size):
        if is_value_defined(arr[i].value):
            results.append(int(arr[i].value))
        else:
            results.append(None)
    return results

# ============================================================================
# RESET AND DONE HELPERS
# ============================================================================
async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=10000):
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f'Timeout: done not asserted after {max_cycles} cycles')

async def start_computation(dut):
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# MAIN TEST
# ============================================================================
@cocotb.test(timeout_time=10000, timeout_unit='ms')
async def test_traveling_salesman(dut):
    'Test the traveling_salesman module.'
    
    # Start clock (10 ns period)
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases
    test_cases = [
        {
            'n': 4,
            'm': 4,
            'edges': [(1,2), (1,3), (2,4), (3,4)],
            'expected_flights': 1,
            'expected_airports': 0b00001111,  # bits 0-3 set (cities 1-4)
        },
        {
            'n': 4,
            'm': 3,
            'edges': [(1,2), (2,3), (3,4)],
            'expected_flights': 0,
            'expected_airports': 0,
        },
    ]
    
    for tc in test_cases:
        n = tc['n']
        m = tc['m']
        edges = tc['edges']
        exp_flights = tc['expected_flights']
        exp_airports = tc['expected_airports']
        
        dut._log.info(f'Testing n={n}, m={m}')
        
        # Set n and m
        dut.n.value = n
        dut.m.value = m
        
        # Initialize all edges to 0
        for i in range(8):
            dut.edges_a[i].value = 0
            dut.edges_b[i].value = 0
        
        # Set the valid edges
        mask = 0
        for i, (a, b) in enumerate(edges):
            if i >= 8:
                raise TestFailure('Too many edges for testbench (max 8)')
            dut.edges_a[i].value = a
            dut.edges_b[i].value = b
            mask |= (1 << i)
        
        # Set valid_edges mask
        dut.valid_edges.value = mask
        
        # Start computation
        await start_computation(dut)
        
        # Wait for done
        await wait_for_done(dut)
        
        # Read results
        flights = int(dut.flights.value)
        airports = int(dut.airports.value)
        
        # Check flights
        if flights != exp_flights:
            raise TestFailure(f'Flights mismatch: expected {exp_flights}, got {flights}')
        
        # Check airports
        if airports != exp_airports:
            raise TestFailure(f'Airports mismatch: expected {exp_airports:b}, got {airports:b}')
        
        dut._log.info(f'  PASS: flights={flights}, airports={airports:08b}')
    
    dut._log.info('All tests passed!')
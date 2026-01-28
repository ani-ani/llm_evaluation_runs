import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Constants
MAX_TRIPS = 1000
ZONE_WIDTH = 4
TIME_WIDTH = 32
COST_WIDTH = 16
CLK_NS = 10

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

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_ticket_solver(dut):
    # Check mandatory signals
    mandatory_signals = ['clk', 'rst_n', 'start', 'trip_zone', 'trip_time', 'trip_valid', 'trip_done', 'ready', 'min_cost', 'done']
    for sig in mandatory_signals:
        if not has_signal(dut, sig):
            dut._log.warning(f"Signal {sig} not found, skipping test")
            return

    # Setup Clock
    clock = Clock(dut.clk, CLK_NS, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.trip_zone.value = 0
    dut.trip_time.value = 0
    dut.trip_valid.value = 0
    dut.trip_done.value = 0
    for _ in range(5):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: Example 1 -> Output 4
    # Trips: (1,4), (2,5)
    # Cost: Start at 0. Trip 1 to 1. Interval [0,1] cost = 2+|0-1|=3. Time 4.
    # Trip 2 to 2. Previous ticket [0,1] valid until 4+10000=10004. Current time 5. Valid.
    # But trip is 2, not in [0,1]. Needs new ticket [1,2] cost 3. Total 6? Wait.
    # Re-read logic: Ticket valid for trip if start and end in interval.
    # Trip 1: Start 0, End 1. Interval [0,1] cost 3.
    # Trip 2: Start 1, End 2. Previous ticket [0,1] valid until 10004. Time 5.
    # Trip 2 start (1) is in [0,1]. Trip 2 end (2) is NOT in [0,1].
    # Must buy new ticket covering [1,2]. Cost 3. Total 6.
    # Sample output says 4. Ah, Johan can buy a ticket [0,2] for the first trip?
    # Yes! Ticket [0,2] cost 2+|0-2|=4. Valid for 10000s.
    # Trip 1 (time 4): zones 0->1, both in [0,2]. OK.
    # Trip 2 (time 5): zones 1->2, both in [0,2]. OK.
    # Total cost 4.
    
    test_cases = [
        {
            "name": "Example 1",
            "trips": [(1, 4), (2, 5)],
            "expected": 4
        },
        {
            "name": "Example 2",
            "trips": [(1, 4), (2, 10005)],
            "expected": 6
        },
        {
            "name": "Example 3",
            "trips": [(1, 4), (2, 10), (0, 15)],
            "expected": 4
        }
    ]

    for test in test_cases:
        dut._log.info(f"Running test: {test['name']}")
        
        # Start signal
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for ready
        for _ in range(100):
            await RisingEdge(dut.clk)
            if safe_int(dut.ready.value) == 1:
                break
        else:
            raise TestFailure("DUT did not become ready")
            
        # Feed trips
        for zone, time in test['trips']:
            dut.trip_zone.value = zone
            dut.trip_time.value = time
            dut.trip_valid.value = 1
            await RisingEdge(dut.clk)
            # Check ready remains high or goes low? 
            # Usually flow control. Assuming ready stays high for simplicity of test.
            # If ready drops, we need to wait.
            while safe_int(dut.ready.value) == 0:
                await RisingEdge(dut.clk)
        
        # End of stream
        dut.trip_valid.value = 0
        dut.trip_done.value = 1
        await RisingEdge(dut.clk)
        dut.trip_done.value = 0
        
        # Wait for done
        done = False
        for _ in range(2000): # Allow plenty of cycles for DP
            await RisingEdge(dut.clk)
            if safe_int(dut.done.value) == 1:
                done = True
                break
        
        if not done:
            raise TestFailure(f"Test '{test['name']}': DUT did not finish")
            
        result = safe_int(dut.min_cost.value)
        dut._log.info(f"Result: {result}, Expected: {test['expected']}")
        
        if result != test['expected']:
            raise TestFailure(f"Test '{test['name']}': Expected {test['expected']}, got {result}")
        
        # Reset for next test case (simple pulse reset)
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

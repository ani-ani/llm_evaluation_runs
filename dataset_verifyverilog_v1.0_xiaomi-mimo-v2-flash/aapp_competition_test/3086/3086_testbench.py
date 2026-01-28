import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helpers
DATA_WIDTH = 8
ARRAY_SIZE = 16
CLK_NS = 10
MAX_CYCLES = 5000

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def day_to_abs(d, m):
    # Days in months (non-leap year)
    month_days = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
    if m < 1 or m > 12:
        return 0
    if d < 1 or d > month_days[m-1]:
        return 0
    days = sum(month_days[:m-1]) + (d - 1)
    return days

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=10, timeout_unit="ms")
async def test_event_durations(dut):
    # Setup clock
    assert has_signal(dut, 'clk'), "Module must have clk signal"
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases from problem
    test_cases = [
        # Case 1: 1 telescope, 1 event type, expected duration 5
        {
            'n': 1, 'm': 1,
            'telescopes': [
                {'start': (26, 2), 'end': (3, 3), 'events': [1]}
            ],
            'expected': [5],
            'desc': 'Single event, count 1'
        },
        # Case 2: 1 telescope, 1 event type, expected duration 185
        {
            'n': 1, 'm': 1,
            'telescopes': [
                {'start': (26, 2), 'end': (3, 3), 'events': [2]}
            ],
            'expected': [185],
            'desc': 'Single event, count 2'
        },
        # Case 3: 3 telescopes, 3 event types
        {
            'n': 3, 'm': 3,
            'telescopes': [
                {'start': (22, 3), 'end': (1, 10), 'events': [9, 10, 10]},
                {'start': (5, 5), 'end': (16, 12), 'events': [1, 7, 10]},
                {'start': (20, 6), 'end': (15, 1), 'events': [4, 9, 10]}
            ],
            'expected': [102, 204, 125],
            'desc': 'Multiple telescopes and events'
        }
    ]
    
    passed = 0
    failed = 0
    
    for tc_idx, tc in enumerate(test_cases):
        cocotb.log.info(f"Test {tc_idx+1}: {tc['desc']}")
        
        try:
            # Setup inputs
            dut.n_telem.value = tc['n']
            dut.m_types.value = tc['m']
            
            # Convert dates and set telescope data
            for i, tel in enumerate(tc['telescopes']):
                start_abs = day_to_abs(tel['start'][0], tel['start'][1])
                end_abs = day_to_abs(tel['end'][0], tel['end'][1])
                
                # Set signals
                dut.__getattr__(f'start_day_{i}').value = start_abs
                dut.__getattr__(f'end_day_{i}').value = end_abs
                
                # Set events
                for j, ev_count in enumerate(tel['events']):
                    dut.__getattr__(f'events_{i}_{j}').value = ev_count
            
            # Start computation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Check results
            valid = int(dut.valid.value)
            
            if valid == 0:
                raise TestFailure(f"Solution not found (valid=0)")
            
            # Read results
            results = []
            for j in range(tc['m']):
                res_val = int(dut.__getattr__(f'result_{j}').value)
                results.append(res_val)
            
            # Verify
            if len(results) != len(tc['expected']):
                raise TestFailure(f"Result length mismatch: {len(results)} vs {len(tc['expected'])}")
            
            for j, (got, exp) in enumerate(zip(results, tc['expected'])):
                if got != exp:
                    raise TestFailure(f"Event {j}: Expected {exp}, got {got}")
            
            passed += 1
            cocotb.log.info(f"PASSED: Results = {results}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
        
        # Reset for next test
        await reset_dut(dut)
    
    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")
    
    cocotb.log.info(f"All tests passed: {passed}/{passed + failed}")
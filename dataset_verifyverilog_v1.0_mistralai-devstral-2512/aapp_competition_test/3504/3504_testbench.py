import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

DATA_WIDTH = 8
ARRAY_SIZE = 16
CLK_NS = 10
MAX_CYCLES = 1000

# Helpers
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

def python_solution(droplets, sensors):
    """Python reference implementation"""
    results = []
    for d_x, d_y in droplets:
        best_y = 0
        for s_x1, s_x2, s_y in sensors:
            if s_y < d_y and s_x1 <= d_x <= s_x2:
                best_y = max(best_y, s_y)
        results.append(best_y)
    return results

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_antimatter_rain(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases from problem
    test_cases = [
        {
            'droplets': [(1, 8), (2, 3), (2, 8), (5, 8), (5, 9)],
            'sensors': [(3, 6, 6), (1, 7, 4), (1, 3, 1)],
            'expected': [4, 1, 4, 6, 0],
            'desc': 'Sample 1'
        },
        {
            'droplets': [(1, 2), (4, 8), (5, 10), (6, 10), (7, 10), (8, 10)],
            'sensors': [(1, 1, 1), (3, 4, 3), (5, 7, 9)],
            'expected': [1, 3, 9, 9, 9, 0],
            'desc': 'Sample 2'
        },
        {
            'droplets': [(1, 5), (3, 5), (5, 5)],
            'sensors': [(2, 4, 3), (1, 5, 2)],
            'expected': [2, 3, 2],
            'desc': 'Overlapping sensor x-ranges'
        },
        {
            'droplets': [(10, 10), (20, 5)],
            'sensors': [(5, 15, 8), (25, 30, 3)],
            'expected': [8, 0],
            'desc': 'No collision for second droplet'
        }
    ]
    
    passed = failed = 0
    
    for tc in test_cases:
        desc = tc['desc']
        droplets = tc['droplets']
        sensors = tc['sensors']
        expected = tc['expected']
        
        cocotb.log.info(f"Testing {desc}")
        
        # Clamp coordinates to 8-bit
        droplets_clamped = [(clamp_to_width(x, DATA_WIDTH), clamp_to_width(y, DATA_WIDTH)) for x, y in droplets]
        sensors_clamped = [(clamp_to_width(x1, DATA_WIDTH), clamp_to_width(x2, DATA_WIDTH), clamp_to_width(y, DATA_WIDTH)) for x1, x2, y in sensors]
        
        try:
            # Write droplet data
            if has_signal(dut, 'd_x') and has_signal(dut, 'd_y'):
                for i in range(ARRAY_SIZE):
                    if i < len(droplets_clamped):
                        dut.d_x[i].value = droplets_clamped[i][0]
                        dut.d_y[i].value = droplets_clamped[i][1]
                    else:
                        dut.d_x[i].value = 0
                        dut.d_y[i].value = 0
            
            # Write sensor data
            if has_signal(dut, 's_x1') and has_signal(dut, 's_x2') and has_signal(dut, 's_y'):
                for i in range(ARRAY_SIZE):
                    if i < len(sensors_clamped):
                        dut.s_x1[i].value = sensors_clamped[i][0]
                        dut.s_x2[i].value = sensors_clamped[i][1]
                        dut.s_y[i].value = sensors_clamped[i][2]
                    else:
                        dut.s_x1[i].value = 0
                        dut.s_x2[i].value = 0
                        dut.s_y[i].value = 0
            
            # Write counts
            if has_signal(dut, 'num_droplets'):
                dut.num_droplets.value = len(droplets_clamped)
            if has_signal(dut, 'num_sensors'):
                dut.num_sensors.value = len(sensors_clamped)
            
            # Start processing
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Process all droplets
                for i, exp in enumerate(expected):
                    await wait_for_done(dut, max_cycles=200)
                    
                    if not is_value_defined(dut.result.value):
                        raise TestFailure(f"Result undefined for droplet {i}")
                    
                    result = int(dut.result.value)
                    if result != exp:
                        raise TestFailure(f"Droplet {i}: Expected {exp}, got {result}")
                    
                    # Wait for next droplet
                    await RisingEdge(dut.clk)
            else:
                # Combinational - wait for settling
                await Timer(100, units='ns')
                
                # Check result
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result undefined")
                
                result = int(dut.result.value)
                if result != expected[0]:
                    raise TestFailure(f"Expected {expected[0]}, got {result}")
            
            cocotb.log.info(f"  PASS: {desc}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL {desc}: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed")
    
    cocotb.log.info(f"All tests passed: {passed}/{passed + failed}")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_random_cases(dut):
    """Test with random small inputs"""
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    random.seed(42)
    
    for test_num in range(3):
        # Generate random test case
        num_d = random.randint(1, 5)
        num_s = random.randint(0, 4)
        
        droplets = []
        for _ in range(num_d):
            x = random.randint(1, 50)
            y = random.randint(5, 100)
            droplets.append((x, y))
        
        sensors = []
        for _ in range(num_s):
            x1 = random.randint(1, 50)
            x2 = random.randint(x1, 50)
            y = random.randint(1, 40)  # Lower than droplets usually
            sensors.append((x1, x2, y))
        
        # Compute expected
        expected = []
        for d_x, d_y in droplets:
            best_y = 0
            for s_x1, s_x2, s_y in sensors:
                if s_y < d_y and s_x1 <= d_x <= s_x2:
                    best_y = max(best_y, s_y)
            expected.append(best_y)
        
        cocotb.log.info(f"Random test {test_num+1}: {len(droplets)} droplets, {len(sensors)} sensors")
        
        try:
            # Write data
            if has_signal(dut, 'd_x'):
                for i in range(ARRAY_SIZE):
                    dut.d_x[i].value = 0
                    dut.d_y[i].value = 0
                for i, (x, y) in enumerate(droplets):
                    dut.d_x[i].value = clamp_to_width(x, DATA_WIDTH)
                    dut.d_y[i].value = clamp_to_width(y, DATA_WIDTH)
            
            if has_signal(dut, 's_x1'):
                for i in range(ARRAY_SIZE):
                    dut.s_x1[i].value = 0
                    dut.s_x2[i].value = 0
                    dut.s_y[i].value = 0
                for i, (x1, x2, y) in enumerate(sensors):
                    dut.s_x1[i].value = clamp_to_width(x1, DATA_WIDTH)
                    dut.s_x2[i].value = clamp_to_width(x2, DATA_WIDTH)
                    dut.s_y[i].value = clamp_to_width(y, DATA_WIDTH)
            
            if has_signal(dut, 'num_droplets'):
                dut.num_droplets.value = len(droplets)
            if has_signal(dut, 'num_sensors'):
                dut.num_sensors.value = len(sensors)
            
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                for i, exp in enumerate(expected):
                    await wait_for_done(dut, max_cycles=200)
                    result = int(dut.result.value)
                    if result != exp:
                        raise TestFailure(f"Droplet {i}: Expected {exp}, got {result}")
                    await RisingEdge(dut.clk)
            else:
                await Timer(100, units='ns')
                result = int(dut.result.value)
                if result != expected[0]:
                    raise TestFailure(f"Expected {expected[0]}, got {result}")
            
            cocotb.log.info(f"  PASS")
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            raise TestFailure(f"Random test failed: {e}")

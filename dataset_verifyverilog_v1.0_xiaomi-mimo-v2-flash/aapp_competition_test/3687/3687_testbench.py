import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Constants
CLK_NS = 10  # 100 MHz
MAX_CYCLES = 500
DATA_WIDTH = 16
ARRAY_SIZE = 8
MAX_WINDOWS = 16

# Scaling constants (from original constraints)
SCALE_FACTOR = 1000000 // 8192  # ~122, for scaling values
CAPACITY_SCALED = 8192

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except (ValueError, AttributeError): return False

def safe_int(v, default=0):
    try: return int(v)
    except (ValueError, AttributeError): return default

def clamp_to_width(v, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

# Array handling for testbench inputs
def pack_sensor_data(values, width=16, num_sensors=8):
    """Pack 16-bit sensor values into a single 128-bit vector"""
    packed = 0
    for i in range(min(num_sensors, len(values))):
        packed |= (clamp_to_width(values[i], width) << (i * width))
    return packed

def pack_bandwidths(values, width=16, num_windows=16):
    """Pack 16-bit bandwidth values into a single 256-bit vector"""
    packed = 0
    for i in range(min(num_windows, len(values))):
        packed |= (clamp_to_width(values[i], width) << (i * width))
    return packed

def scale_value(v):
    """Scale input value from original to simulation units"""
    # Scale to fit 16-bit: original 10^6 -> 65535 max
    return (v * 65535) // 1000000

def scale_capacity(v):
    """Scale queue capacity"""
    return CAPACITY_SCALED  # Fixed for all queues in simulation

async def reset_dut(dut, cycles=2):
    """Reset the DUT"""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=500):
    """Wait for done signal"""
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def write_sensor_data(dut, values, num_sensors=8):
    """Write sensor data to module"""
    # Check if packed or individual
    if has_signal(dut, 'sensor_data'):
        # Packed format
        packed = pack_sensor_data(values, DATA_WIDTH, num_sensors)
        dut.sensor_data.value = packed
    else:
        # Individual signals
        for i in range(num_sensors):
            if has_signal(dut, f'sensor_data_{i}'):
                val = values[i] if i < len(values) else 0
                getattr(dut, f'sensor_data_{i}').value = clamp_to_width(val, DATA_WIDTH)
            else:
                break

async def write_bandwidths(dut, values, num_windows=16):
    """Write downlink bandwidths to module"""
    if has_signal(dut, 'downlink_bandwidth'):
        packed = pack_bandwidths(values, DATA_WIDTH, num_windows)
        dut.downlink_bandwidth.value = packed
    else:
        for i in range(num_windows):
            if has_signal(dut, f'bandwidth_{i}'):
                val = values[i] if i < len(values) else 0
                getattr(dut, f'bandwidth_{i}').value = clamp_to_width(val, DATA_WIDTH)
            else:
                break

async def write_sensor_queue_map(dut, values):
    """Write sensor to queue mapping"""
    if has_signal(dut, 'sensor_queue_map'):
        # Pack into single byte per sensor (8 sensors = 64-bit)
        packed = 0
        for i in range(min(8, len(values))):
            packed |= (clamp_to_width(values[i], 3) << (i * 4))
        dut.sensor_queue_map.value = packed
    else:
        for i in range(8):
            if has_signal(dut, f'sensor_queue_map_{i}'):
                val = values[i] if i < len(values) else 0
                getattr(dut, f'sensor_queue_map_{i}').value = val
            else:
                break

async def write_queue_capacity(dut, values):
    """Write queue capacities"""
    if has_signal(dut, 'queue_capacity'):
        packed = 0
        for i in range(min(8, len(values))):
            packed |= (clamp_to_width(values[i], 16) << (i * 16))
        dut.queue_capacity.value = packed
    else:
        for i in range(8):
            if has_signal(dut, f'queue_capacity_{i}'):
                val = values[i] if i < len(values) else 0
                getattr(dut, f'queue_capacity_{i}').value = clamp_to_width(val, 16)
            else:
                break

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_probe_system(dut):
    """Test the probe downlink system"""
    # Setup
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases
    test_cases = [
        # Example 1: Possible
        {
            'name': 'Possible - 2 windows, 2 queues, 2 sensors',
            'sensor_queue_map': [0, 1, 0, 0, 0, 0, 0, 0],
            'queue_capacity': [CAPACITY_SCALED, CAPACITY_SCALED, CAPACITY_SCALED, CAPACITY_SCALED, 
                             CAPACITY_SCALED, CAPACITY_SCALED, CAPACITY_SCALED, CAPACITY_SCALED],
            'windows': [
                {'bandwidth': scale_value(5000), 'sensor_data': [scale_value(2000), scale_value(2000), 0, 0, 0, 0, 0, 0]},
                {'bandwidth': scale_value(5000), 'sensor_data': [scale_value(2000), scale_value(2000), 0, 0, 0, 0, 0, 0]},
            ],
            'expected_result': 1
        },
        # Example 2: Impossible
        {
            'name': 'Impossible - insufficient bandwidth',
            'sensor_queue_map': [0, 1, 0, 0, 0, 0, 0, 0],
            'queue_capacity': [CAPACITY_SCALED, CAPACITY_SCALED, CAPACITY_SCALED, CAPACITY_SCALED,
                             CAPACITY_SCALED, CAPACITY_SCALED, CAPACITY_SCALED, CAPACITY_SCALED],
            'windows': [
                {'bandwidth': scale_value(1000), 'sensor_data': [scale_value(2000), scale_value(2000), 0, 0, 0, 0, 0, 0]},
                {'bandwidth': scale_value(5000), 'sensor_data': [scale_value(2000), scale_value(2000), 0, 0, 0, 0, 0, 0]},
            ],
            'expected_result': 0
        },
        # Example 3: Single window
        {
            'name': 'Single window - all data fits',
            'sensor_queue_map': [0, 0, 0, 0, 0, 0, 0, 0],
            'queue_capacity': [CAPACITY_SCALED, CAPACITY_SCALED, CAPACITY_SCALED, CAPACITY_SCALED,
                             CAPACITY_SCALED, CAPACITY_SCALED, CAPACITY_SCALED, CAPACITY_SCALED],
            'windows': [
                {'bandwidth': scale_value(10000), 'sensor_data': [scale_value(5000), scale_value(5000), 0, 0, 0, 0, 0, 0]},
            ],
            'expected_result': 1
        },
    ]
    
    passed = 0
    failed = 0
    
    for test_case in test_cases:
        cocotb.log.info(f"Test: {test_case['name']}")
        try:
            # Write configuration
            await write_sensor_queue_map(dut, test_case['sensor_queue_map'])
            await write_queue_capacity(dut, test_case['queue_capacity'])
            
            # Write bandwidths for all windows (padded to 16)
            bandwidths = [w['bandwidth'] for w in test_case['windows']]
            await write_bandwidths(dut, bandwidths, num_windows=16)
            
            # Process each window
            for idx, window in enumerate(test_case['windows']):
                # Write sensor data for current window
                await write_sensor_data(dut, window['sensor_data'], num_sensors=8)
                
                # Start processing this window
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done (max 16 cycles per window)
                max_wait = 20
                for _ in range(max_wait):
                    await RisingEdge(dut.clk)
                    if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                        break
                else:
                    raise TestFailure(f"Done not asserted after {max_wait} cycles")
                
                # Check status
                if has_signal(dut, 'status'):
                    status = int(dut.status.value)
                    if status == 2:  # Overflow error
                        break
            
            # Final result check
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            if result != test_case['expected_result']:
                raise TestFailure(f"Expected {test_case['expected_result']}, got {result}")
            
            passed += 1
            cocotb.log.info(f"PASS: {test_case['name']}")
            
        except TestFailure as e:
            failed += 1
            cocotb.log.error(f"FAIL: {test_case['name']} - {e}")
        
        # Reset between test cases
        await reset_dut(dut)
    
    if failed:
        raise TestFailure(f"{failed} out of {passed + failed} tests failed")
    
    cocotb.log.info(f"All {passed} tests passed")

import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Scaling factors: time 0-127 (scale 0.5), irritation 0-63 (scale 1.0)
MAX_CARS = 20
CLK_NS = 10

def scale_time(val, max_val=127):
    return min(val // 2, max_val)

def scale_irr(val, max_val=63):
    return min(val, max_val)

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=2000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def configure_dut(dut, t, cars):
    # Set t (8-bit)
    dut.cfg_t.value = clamp_to_width(scale_time(t), 8)
    # Set n (5-bit)
    dut.cfg_n.value = clamp_to_width(len(cars), 5)
    
    # Set car configs
    for i in range(MAX_CARS):
        dir_bit = 0
        arr_val = 0
        irr_val = 0
        if i < len(cars):
            d, a, r = cars[i]
            dir_bit = 1 if d == 'E' else 0
            arr_val = clamp_to_width(scale_time(a), 7)
            irr_val = clamp_to_width(scale_irr(r), 6)
        
        # Access individual array elements
        if has_signal(dut, f'cfg_car_dir_{i}'):
            getattr(dut, f'cfg_car_dir_{i}').value = dir_bit
        elif has_signal(dut, 'cfg_car_dir'):
            dut.cfg_car_dir[i].value = dir_bit
        
        if has_signal(dut, f'cfg_car_arr_{i}'):
            getattr(dut, f'cfg_car_arr_{i}').value = arr_val
        elif has_signal(dut, 'cfg_car_arr'):
            dut.cfg_car_arr[i].value = arr_val
        
        if has_signal(dut, f'cfg_car_irr_{i}'):
            getattr(dut, f'cfg_car_irr_{i}').value = irr_val
        elif has_signal(dut, 'cfg_car_irr'):
            dut.cfg_car_irr[i].value = irr_val

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_traffic(dut):
    # Setup clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    test_cases = [
        {
            't': 8,
            'cars': [('W', 10, 0), ('W', 10, 3), ('E', 17, 4)],
            'expected': 0,
            'desc': 'Sample 1'
        },
        {
            't': 100,
            'cars': [
                ('W', 0, 200), ('W', 5, 201), ('E', 95, 1111),
                ('E', 95, 1), ('E', 95, 11)
            ],
            'expected': 1,
            'desc': 'Sample 2'
        }
    ]
    
    passed = 0
    failed = 0
    
    for tc in test_cases:
        cocotb.log.info(f"Test: {tc['desc']} (t={tc['t']}, n={len(tc['cars'])})")
        
        try:
            # Configure inputs
            await configure_dut(dut, tc['t'], tc['cars'])
            
            # Start computation
            if has_signal(dut, 'start'):
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
            else:
                await RisingEdge(dut.clk)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            result = int(dut.result.value)
            if result != tc['expected']:
                raise TestFailure(f"Expected {tc['expected']}, got {result}")
            
            passed += 1
            cocotb.log.info(f"PASS: Result {result}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
        
        # Reset for next test
        await reset_dut(dut)
    
    if failed:
        raise TestFailure(f"{failed} tests failed")
import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 12
RESULT_WIDTH = 16
N_WIDTH = 7
CLK_NS = 10
MAX_CYCLES = 200

# Helper functions
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
    # Handle signed vs unsigned
    if v < 0:
        max_val = (1 << (bits-1))
        min_val = -(1 << (bits-1))
    else:
        max_val = (1 << bits) - 1
        min_val = 0
    return min(max_val, max(min_val, v))

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    if has_signal(dut, 'temp_valid'): dut.temp_valid.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def send_temperatures(dut, temps):
    """Send temperature sequence to DUT"""
    dut.ready.value = 1
    dut.temp_valid.value = 1
    dut.temp_data.value = 0
    
    # Wait for module to be ready
    if has_signal(dut, 'ready'):
        for _ in range(100):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.ready.value) and int(dut.ready.value) == 1:
                break
    
    # Send each temperature
    for i, temp in enumerate(temps):
        # Clamp to 12-bit signed range
        clamped = clamp_to_width(temp, DATA_WIDTH)
        dut.temp_data.value = from_signed(clamped, DATA_WIDTH) if clamped < 0 else clamped
        dut.temp_valid.value = 1
        await RisingEdge(dut.clk)
    
    dut.temp_valid.value = 0

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_weather_prediction(dut):
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases: (temps, expected_result, description)
    test_cases = [
        ([10, 5, 0, -5, -10], -15, "Arithmetic progression negative"),
        ([1, 1, 1, 1], 1, "Constant sequence"),
        ([5, 1, -5], -5, "Not arithmetic progression"),
        ([900, 1000], 1100, "Simple arithmetic progression"),
        ([1, 2], 3, "Simple positive progression"),
        ([2, 5, 8], 11, "Arithmetic progression"),
        ([4, 1, -2, -5], -8, "Arithmetic progression negative"),
        ([-1000, -995, -990, -985, -980, -975, -970, -965, -960, -955], -950, "Large negative progression"),
        ([-1000, -800, -600, -400, -200, 0, 200, 400, 600, 800, 1000], 1200, "Large positive progression"),
        ([1000, 978, 956, 934, 912, 890, 868, 846, 824, 802, 780, 758, 736, 714, 692, 670, 648, 626, 604, 582, 560, 538, 516, 494, 472, 450, 428, 406, 384, 362, 340], 318, "Complex arithmetic progression"),
        ([1000, 544, 88, -368, -824], -1280, "Arithmetic progression large step"),
        ([1000, 1000], 1000, "Two equal values"),
        ([-1000, 1000], 3000, "Large positive difference"),
        ([1000, -1000], -3000, "Large negative difference"),
        ([-1000, -1000], -1000, "Two equal negative values"),
    ]
    
    passed = failed = 0
    
    for test_idx, (temps, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {test_idx+1}: {description} - temps={temps}")
        
        try:
            # Set start signal
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Send temperatures
            for i, temp in enumerate(temps):
                # Wait for ready
                timeout = 100
                for _ in range(timeout):
                    await RisingEdge(dut.clk)
                    if is_value_defined(dut.ready.value) and int(dut.ready.value) == 1:
                        break
                
                # Send temperature
                clamped = clamp_to_width(temp, DATA_WIDTH)
                if clamped < 0:
                    dut.temp_data.value = from_signed(clamped, DATA_WIDTH)
                else:
                    dut.temp_data.value = clamped
                dut.temp_valid.value = 1
                await RisingEdge(dut.clk)
            
            dut.temp_valid.value = 0
            
            # Wait for done
            await wait_for_done(dut, 200)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            result_val = int(dut.result.value)
            # Convert from unsigned to signed
            if result_val >= (1 << (RESULT_WIDTH-1)):
                result_val -= (1 << RESULT_WIDTH)
            
            if result_val != expected:
                raise TestFailure(f"Expected {expected}, got {result_val}")
            
            passed += 1
            cocotb.log.info(f"PASS: result={result_val}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
        
        # Reset for next test
        await reset_dut(dut)
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
    cocotb.log.info(f"All {passed} tests passed!")

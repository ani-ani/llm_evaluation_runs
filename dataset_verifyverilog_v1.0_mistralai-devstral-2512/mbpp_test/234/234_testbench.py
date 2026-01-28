import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout waiting for done signal after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_volume_cube(dut):
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (side, expected_volume)
    test_cases = [
        (3, 27),
        (2, 8),
        (5, 125),
        (0, 0),
        (10, 1000),
        (255, 16581375)
    ]
    
    passed = 0
    failed = 0
    
    for side, expected_volume in test_cases:
        cocotb.log.info(f"Testing side={side}, expected volume={expected_volume}")
        
        try:
            # Assert start pulse
            dut.start.value = 1
            dut.side.value = clamp_to_width(side, 8)
            await RisingEdge(dut.clk)
            
            # Deassert start
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.volume.value):
                raise TestFailure("Volume output is undefined")
            
            result = int(dut.volume.value)
            if result != expected_volume:
                raise TestFailure(f"Expected volume {expected_volume}, got {result}")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL (side={side}): {e}")
            failed += 1
        
        # Wait one cycle to ensure done goes low before next test
        await RisingEdge(dut.clk)
    
    if failed > 0:
        raise TestFailure(f"{failed} out of {len(test_cases)} tests failed")
import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helpers
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

# Constants
DATA_WIDTH = 8
MAX_CYCLES = 256
CLK_NS = 10

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_wire_bending(dut):
    # Setup clock and reset
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        dut.rst_n.value = 0
        dut.start.value = 0
        for _ in range(2):
            await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    else:
        await Timer(100, units='ns')
    
    # Test cases: (bends, expected_result)
    # Bend: (distance, dir) where dir: 0=CW, 1=CCW
    test_cases = [
        # GHOST case: bends at 3,2,1 on length 4
        ([(3,0), (2,0), (1,0)], 1, "simple ghost"),
        # SAFE case: bends at 1,2,3 on length 3
        ([(1,0), (2,0), (3,0)], 0, "simple safe"),
    ]
    
    passed = 0
    failed = 0
    
    for bends, expected, desc in test_cases:
        cocotb.log.info(f"Test: {desc} with {len(bends)} bends")
        try:
            # Initialize for each test
            if has_signal(dut, 'clk'):
                dut.rst_n.value = 0
                await RisingEdge(dut.clk)
                await RisingEdge(dut.clk)
                dut.rst_n.value = 1
                await RisingEdge(dut.clk)
            
            # Send bend sequence
            for i, (dist, dir_val) in enumerate(bends):
                if has_signal(dut, 'clk'):
                    dut.bend_dist.value = clamp_to_width(dist, 16)
                    dut.bend_dir.value = dir_val
                    dut.bend_valid.value = 1
                    dut.bend_last.value = 1 if i == len(bends) - 1 else 0
                    
                    if i == 0:
                        dut.start.value = 1
                        await RisingEdge(dut.clk)
                        dut.start.value = 0
                    else:
                        await RisingEdge(dut.clk)
                    
                    dut.bend_valid.value = 0
                    
                    # Wait for bend completion (simulated wait)
                    await Timer(50, units='ns')
                else:
                    # Combinational logic
                    await Timer(10, units='ns')
                    break
            
            # Wait for completion
            if has_signal(dut, 'clk'):
                max_wait = 200
                for _ in range(max_wait):
                    await RisingEdge(dut.clk)
                    if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                        break
            else:
                await Timer(200, units='ns')
            
            # Check result
            if not has_signal(dut, 'result'):
                raise TestFailure("No result signal found")
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            cocotb.log.info(f"PASS: {desc}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
        
        # Small delay between tests
        await Timer(100, units='ns')
    
    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")

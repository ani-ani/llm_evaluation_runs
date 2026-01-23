import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# MANDATORY HELPER FUNCTIONS
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
    return min(max_val, max(0, value))

# CONFIGURATION
DATA_WIDTH = 32
CLK_PERIOD_NS = 10
MAX_CYCLES = 10000

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_robot_reach(dut):
    """Test the robot reach module."""
    
    # Detect if sequential
    is_sequential = has_signal(dut, 'clk')
    
    if is_sequential:
        # Start clock
        cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
        
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        dut.char_valid.value = 0
        await Timer(20, units='ns')
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    # Test cases: (a, b, command_string, expected_result)
    test_cases = [
        (2, 2, "RU", True),
        (1, 2, "RU", False),
        (-1, 1000000000, "LRRLU", True),
        (0, 0, "D", True),
        (0, 0, "UURRDL", True),
        (987654321, 987654321, "UURRDL", True),
        (4, 2, "UURRDL", False),
        (4, 3, "UURRDL", True),
        (4, 4, "UURRDL", True),
        (4, 6, "UURRDL", True),
        (4, 7, "UURRDL", False),
        (1000000000, 1000000000, "UURRDL", True),
        (-1, -1, "UR", False),
        (1, 1, "UURRDDLL", True),
        (987654321, 2, "UURDD", False),
        (0, 123456789, "RRULL", True),
        (4, 4, "UUUURRRRDDDDLLLL", True),
    ]
    
    passed = 0
    failed = 0
    
    for i, (a, b, command, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: ({a}, {b}) with command '{command}' -> {'Yes' if expected else 'No'}")
        
        try:
            if is_sequential:
                # Reset for new test
                dut.rst_n.value = 0
                await RisingEdge(dut.clk)
                dut.rst_n.value = 1
                await RisingEdge(dut.clk)
                
                # Set target and length
                dut.a.value = from_signed(a, DATA_WIDTH)
                dut.b.value = from_signed(b, DATA_WIDTH)
                dut.len.value = len(command)
                
                # Provide command string
                for j, c in enumerate(command):
                    dut.char.value = ord(c)
                    dut.char_valid.value = 1
                    await RisingEdge(dut.clk)
                    # Wait for character to be processed
                    timeout = 0
                    while timeout < 100:
                        if is_value_defined(dut.count.value) and int(dut.count.value) == j+1:
                            break
                        await RisingEdge(dut.clk)
                        timeout += 1
                    else:
                        raise TestFailure(f"Timeout waiting for character {j} to be processed")
                dut.char_valid.value = 0
                
                # Start computation
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                timeout_counter = 0
                while timeout_counter < MAX_CYCLES:
                    await RisingEdge(dut.clk)
                    if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                        break
                    timeout_counter += 1
                else:
                    raise TestFailure(f"Timeout waiting for done")
                
                # Read result
                if not is_value_defined(dut.result.value):
                    raise TestFailure(f"Result is undefined (X/Z)")
                
                result = bool(int(dut.result.value))
                
                if result != expected:
                    raise TestFailure(f"Expected {'Yes' if expected else 'No'}, got {'Yes' if result else 'No'}")
                
                cocotb.log.info(f"  PASS")
                passed += 1
            else:
                cocotb.log.warning("Combinational module detected - skipping")
                continue
                
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
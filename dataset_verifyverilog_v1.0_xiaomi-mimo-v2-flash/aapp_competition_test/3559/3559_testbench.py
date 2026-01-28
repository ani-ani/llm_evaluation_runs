import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# MANDATORY HELPERS
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

# Constants for this test
DATA_WIDTH = 8
CLK_NS = 10
MAX_CYCLES = 5000  # Allow plenty of time for simulation logic

def to_ascii(c):
    return ord(c)

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_zergling_rush(dut):
    # Setup Clock
    if not has_signal(dut, 'clk'):
        raise TestFailure("Module missing 'clk' signal")
    
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    if has_signal(dut, 'config_data'): dut.config_data.value = 0
    if has_signal(dut, 'config_addr'): dut.config_addr.value = 0
    if has_signal(dut, 'map_data'): dut.map_data.value = 0
    
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # --- Test Case 1: Simple Input ---
    # Input: "2\n0 0\n0 0\n1.\n..\n0\n"
    # N=2, Upgrades=0,0,0,0, Map: 1., .., Turns=0
    # Expected Output: 1., ..
    
    dut._log.info("Test Case 1: N=2, 0 turns")
    
    # Wait for ready
    if not is_value_defined(dut.ready):
        await Timer(1000, units='ns')
    
    max_wait = 100
    for _ in range(max_wait):
        if is_value_defined(dut.ready) and int(dut.ready) == 1:
            break
        await RisingEdge(dut.clk)
    else:
        raise TestFailure("Module never signaled ready")
    
    # 1. Configure N=2
    dut.config_addr.value = 0 # N
    dut.config_data.value = 2
    await RisingEdge(dut.clk)
    
    # 2. Configure Upgrades (all 0)
    # P1 Atk (addr 1), P1 Arm (addr 2), P2 Atk (addr 3), P2 Arm (addr 4)
    dut.config_addr.value = 1
    dut.config_data.value = 0
    await RisingEdge(dut.clk)
    dut.config_addr.value = 2
    dut.config_data.value = 0
    await RisingEdge(dut.clk)
    dut.config_addr.value = 3
    dut.config_data.value = 0
    await RisingEdge(dut.clk)
    dut.config_addr.value = 4
    dut.config_data.value = 0
    await RisingEdge(dut.clk)
    
    # 3. Configure Turns = 0
    dut.config_addr.value = 5
    dut.config_data.value = 0
    await RisingEdge(dut.clk)
    
    # 4. Load Map (Row Major)
    # Map: "1.\n.." -> '1', '.', '.', '.'
    map_chars = ['1', '.', '.', '.']
    for c in map_chars:
        # Wait for ready to be high before loading if the module requires it
        # In a robust design, ready stays high during loading or we check status
        if is_value_defined(dut.ready) and int(dut.ready) == 0:
             # If ready drops, wait. (Depends on design, assume it stays high or we poll)
             pass
        dut.map_data.value = to_ascii(c)
        await RisingEdge(dut.clk)
    
    # Wait for done
    done = False
    for _ in range(MAX_CYCLES):
        if is_value_defined(dut.done) and int(dut.done) == 1:
            done = True
            break
        await RisingEdge(dut.clk)
    
    if not done:
        raise TestFailure("Module never signaled done")
    
    # 5. Read Output
    # Read 4 cells
    result_map = []
    for i in range(4):
        dut.result_addr.value = i
        await RisingEdge(dut.clk) # Assume 1 cycle read latency or combinational
        # Wait small time for propagation if combinational
        await Timer(1, units='ns')
        if is_value_defined(dut.result_data):
            val = int(dut.result_data)
            char = chr(val)
            result_map.append(char)
        else:
            raise TestFailure(f"Result data undefined at index {i}")
    
    # Construct output string
    output_str = f"{result_map[0]}{result_map[1]}\n{result_map[2]}{result_map[3]}\n"
    expected = "1.\n..\n"
    
    if output_str != expected:
        raise TestFailure(f"Output mismatch. Expected:\n{expected}Got:\n{output_str}")
    
    dut._log.info("Test Case 1 Passed")
    
    # --- Test Case 2: Combat ---
    # Input: "2\n0 0\n0 0\n1.\n.2\n100\n"
    # N=2, Map: 1. .2, Turns=100
    # Expected: "..\n..\n" (Both die eventually)
    
    dut._log.info("Test Case 2: N=2, Combat, 100 turns")
    
    # Reset (Physical or via config reload - let's do logical reload)
    # We will assert start to reset internal logic if available, otherwise rely on sequence
    # Assuming the module reconfigures on 'start' or implicit reset.
    # For this test, we assume we can reload state. 
    # If the design is single-shot, we would need to re-trigger `start` pulse.
    
    # Re-assert start pulse (assuming it resets the loader state)
    if has_signal(dut, 'start'):
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
    
    # Wait for ready again
    for _ in range(max_wait):
        if is_value_defined(dut.ready) and int(dut.ready) == 1:
            break
        await RisingEdge(dut.clk)
    else:
        raise TestFailure("Module never signaled ready for test 2")

    # Configure
    dut.config_addr.value = 0; dut.config_data.value = 2; await RisingEdge(dut.clk)
    dut.config_addr.value = 1; dut.config_data.value = 0; await RisingEdge(dut.clk)
    dut.config_addr.value = 2; dut.config_data.value = 0; await RisingEdge(dut.clk)
    dut.config_addr.value = 3; dut.config_data.value = 0; await RisingEdge(dut.clk)
    dut.config_addr.value = 4; dut.config_data.value = 0; await RisingEdge(dut.clk)
    dut.config_addr.value = 5; dut.config_data.value = 100; await RisingEdge(dut.clk)
    
    # Load Map: "1.", ".2" -> '1', '.', '.', '2'
    map_chars_2 = ['1', '.', '.', '2']
    for c in map_chars_2:
        dut.map_data.value = to_ascii(c)
        await RisingEdge(dut.clk)
    
    # Wait for done
    done = False
    for _ in range(MAX_CYCLES):
        if is_value_defined(dut.done) and int(dut.done) == 1:
            done = True
            break
        await RisingEdge(dut.clk)
    
    if not done:
        raise TestFailure("Module never signaled done for test 2")
        
    # Read Output
    result_map_2 = []
    for i in range(4):
        dut.result_addr.value = i
        await RisingEdge(dut.clk)
        await Timer(1, units='ns')
        val = int(dut.result_data)
        result_map_2.append(chr(val))
    
    output_str_2 = f"{result_map_2[0]}{result_map_2[1]}\n{result_map_2[2]}{result_map_2[3]}\n"
    expected_2 = "..\n..\n"
    
    if output_str_2 != expected_2:
        raise TestFailure(f"Output mismatch. Expected:\n{expected_2}Got:\n{output_str_2}")
    
    dut._log.info("Test Case 2 Passed")

import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration
DATA_WIDTH = 8
MAX_COMPANIES = 4
MAX_PACKS = 4
MAX_SUM = 1024
CLK_PERIOD_NS = 10
MAX_CYCLES = 5000

# Helper functions
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut):
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut):
    for _ in range(MAX_CYCLES):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure("Timeout")

async def start_computation(dut):
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# Test cases
TEST_CASES = [
    {"B": 371, "k": 3, "packs": [[40,65], [100,150], [300,320]], "expected": None},
    {"B": 310, "k": 3, "packs": [[40,65], [100,150], [300,320]], "expected": 300},
    {"B": 90, "k": 2, "packs": [[20,35], [88,200]], "expected": 88},
    {"B": 91, "k": 2, "packs": [[20,35], [88,200]], "expected": 200}
]

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_bolt_pack_finder(dut):
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    await reset_dut(dut)
    
    passed = failed = 0
    
    for test_idx, tc in enumerate(TEST_CASES):
        cocotb.log.info(f"Test {test_idx+1}: B={tc['B']}, k={tc['k']}")
        
        # Flatten pack data
        pack_flat = [0] * (MAX_COMPANIES * MAX_PACKS)
        num_packs = [0] * MAX_COMPANIES
        for i, packs in enumerate(tc['packs']):
            if i >= MAX_COMPANIES: break
            num_packs[i] = min(len(packs), MAX_PACKS)
            for j, p in enumerate(packs):
                if j >= MAX_PACKS: break
                pack_flat[i * MAX_PACKS + j] = p
        
        # Write inputs
        dut.B.value = clamp_to_width(tc['B'], DATA_WIDTH)
        dut.k.value = clamp_to_width(tc['k'], 4)
        for i in range(MAX_COMPANIES * MAX_PACKS):
            dut.pack_sizes[i].value = clamp_to_width(pack_flat[i], DATA_WIDTH)
        for i in range(MAX_COMPANIES):
            dut.num_packs[i].value = clamp_to_width(num_packs[i], 4)
        
        # Execute
        await start_computation(dut)
        try:
            await wait_for_done(dut)
            
            if not is_value_defined(dut.result.value) or not is_value_defined(dut.impossible.value):
                raise TestFailure("Undefined output")
            
            result = int(dut.result.value)
            impossible = int(dut.impossible.value)
            
            if tc['expected'] is None:
                if impossible != 1:
                    raise TestFailure(f"Expected impossible, got {result}")
                cocotb.log.info(f"  PASS: impossible")
            else:
                if impossible == 1:
                    raise TestFailure(f"Expected {tc['expected']}, got impossible")
                if result != tc['expected']:
                    raise TestFailure(f"Expected {tc['expected']}, got {result}")
                cocotb.log.info(f"  PASS: result={result}")
            
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    cocotb.log.info(f"Results: {passed}/{passed+failed} passed")
    if failed:
        raise TestFailure(f"{failed} tests failed")
import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# Grid writing: handle individual signals or arrays
def write_grid(dut, grid, m, n):
    """Write 6x6 grid to DUT. Handles both packed arrays and individual ports."""
    # Try writing to individual cell signals first
    for i in range(m):
        for j in range(n):
            cell_name = f"grid_{i}_{j}"
            if has_signal(dut, cell_name):
                getattr(dut, cell_name).value = clamp_to_width(grid[i][j], 8)
            elif has_signal(dut, 'grid') and hasattr(dut.grid, '__getitem__'):
                # Try array-of-array style
                try:
                    dut.grid[i][j].value = clamp_to_width(grid[i][j], 8)
                except:
                    # Try flattened
                    dut.grid[i*n + j].value = clamp_to_width(grid[i][j], 8)
    
    # Set dimensions
    if has_signal(dut, 'm'):
        dut.m.value = m
    if has_signal(dut, 'n'):
        dut.n.value = n

@cocotb.test(timeout_time=100, timeout_unit='ms')
async def test_grid_completion(dut):
    """Test the grid completion solver."""
    
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)
    
    # Test cases from examples
    test_cases = [
        {
            "name": "Example 1: 3x3",
            "m": 3, "n": 3,
            "grid": [
                [1, 2, 4],
                [0, 3, 6],
                [4, 0, 3]
            ],
            "expected": 2
        },
        {
            "name": "Example 2: 3x4",
            "m": 3, "n": 4,
            "grid": [
                [2, 3, 0, 7],
                [0, 0, 2, 1],
                [0, 0, 3, 0]
            ],
            "expected": 37
        },
        {
            "name": "Example 3: 3x4 variant",
            "m": 3, "n": 4,
            "grid": [
                [1, 3, 0, 7],
                [2, 0, 0, 1],
                [0, 0, 9, 0]
            ],
            "expected": 14
        },
        {
            "name": "Small 3x3 all known",
            "m": 3, "n": 3,
            "grid": [
                [1, 2, 3],
                [4, 5, 6],
                [7, 8, 9]
            ],
            "expected": 1  # Should validate and count as 1 solution
        }
    ]
    
    passed = 0
    failed = 0
    
    for test in test_cases:
        cocotb.log.info(f"Testing: {test['name']}")
        
        try:
            # Write grid to DUT
            write_grid(dut, test['grid'], test['m'], test['n'])
            
            # Start computation
            if has_signal(dut, 'start'):
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
            else:
                # Combinational: wait for propagation
                await Timer(100, units='ns')
            
            # Wait for done
            if has_signal(dut, 'done'):
                await wait_for_done(dut, max_cycles=50000)
            else:
                # For combinational, wait longer
                await Timer(1000, units='ns')
            
            # Read result
            if not has_signal(dut, 'result'):
                raise TestFailure("Result signal not found")
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            result = int(dut.result.value)
            expected = test['expected']
            
            cocotb.log.info(f"Result: {result}, Expected: {expected}")
            
            if result == expected:
                cocotb.log.info(f"PASS: {test['name']}")
                passed += 1
            else:
                raise TestFailure(f"Expected {expected}, got {result}")
                
        except TestFailure as e:
            cocotb.log.error(f"FAIL {test['name']}: {e}")
            failed += 1
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
    
    cocotb.log.info(f"All tests passed: {passed}/{len(test_cases)}")

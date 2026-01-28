import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 10  # For distance values (0-1000)
N_MAX = 15       # Scaled down from 1500
COST_WIDTH = 21  # For total cost (up to 1499 * 1000)
CLK_NS = 10
MAX_CYCLES = 1000

# Helper functions
try:
    int(0)
    def is_value_defined(v):
        try: 
            int(v)
            return True
        except (ValueError, TypeError): 
            return False
except:
    def is_value_defined(v):
        try: 
            int(v)
            return True
        except (ValueError, TypeError): 
            return False

def safe_int(v, default=0):
    try: 
        return int(v)
    except (ValueError, TypeError): 
        return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try: 
        getattr(dut, name)
        return True
    except AttributeError: 
        return False

def clamp_to_width(v, bits):
    max_val = (1 << bits) - 1
    if v < 0:
        return 0
    elif v > max_val:
        return max_val
    else:
        return v

# Main test
@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_tsp_constrained(dut):
    # Check if sequential
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        
        # Reset
        dut.rst_n.value = 0
        if has_signal(dut, 'start'):
            dut.start.value = 0
        for _ in range(2):
            await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    else:
        # Combinational - just wait for result
        await Timer(100, units='ns')
    
    # Test cases
    test_cases = [
        {
            'N': 3,
            'dist': [
                [0, 5, 2],
                [5, 0, 4],
                [2, 4, 0]
            ],
            'expected': 7
        },
        {
            'N': 4,
            'dist': [
                [0, 15, 7, 8],
                [15, 0, 16, 9],
                [7, 16, 0, 12],
                [8, 9, 12, 0]
            ],
            'expected': 31
        }
    ]
    
    passed = 0
    failed = 0
    
    for test_idx, test_case in enumerate(test_cases):
        N = test_case['N']
        dist = test_case['dist']
        expected = test_case['expected']
        
        cocotb.log.info(f"Test {test_idx + 1}: N={N}, expected={expected}")
        
        try:
            if is_seq:
                # Reset again for each test
                dut.rst_n.value = 0
                await RisingEdge(dut.clk)
                await RisingEdge(dut.clk)
                dut.rst_n.value = 1
                await RisingEdge(dut.clk)
            
            # Write N
            if has_signal(dut, 'N_in'):
                dut.N_in.value = clamp_to_width(N, 4)
            
            # Write distance matrix
            # Assuming interface: data_in, row, col, write_en
            if all(has_signal(dut, s) for s in ['data_in', 'row', 'col', 'write_en']):
                for i in range(N):
                    for j in range(N):
                        dut.data_in.value = clamp_to_width(dist[i][j], DATA_WIDTH)
                        dut.row.value = i
                        dut.col.value = j
                        dut.write_en.value = 1
                        if is_seq:
                            await RisingEdge(dut.clk)
                        else:
                            await Timer(1, units='ns')
                        dut.write_en.value = 0
            
            # Start computation
            if has_signal(dut, 'start'):
                dut.start.value = 1
                if is_seq:
                    await RisingEdge(dut.clk)
                else:
                    await Timer(1, units='ns')
                dut.start.value = 0
            
            # Wait for done
            if is_seq:
                max_wait = 1000
                for _ in range(max_wait):
                    await RisingEdge(dut.clk)
                    if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                        break
                else:
                    raise TestFailure(f"Timeout after {max_wait} cycles")
            else:
                await Timer(100, units='ns')
            
            # Read result
            if has_signal(dut, 'min_cost'):
                result = int(dut.min_cost.value)
                cocotb.log.info(f"Result: {result}, Expected: {expected}")
                
                if result != expected:
                    raise TestFailure(f"Expected {expected}, got {result}")
                passed += 1
            else:
                raise TestFailure("min_cost signal not found")
                
        except TestFailure as e:
            cocotb.log.error(f"Test {test_idx + 1} FAILED: {e}")
            failed += 1
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
    
    cocotb.log.info(f"All tests passed: {passed}/{len(test_cases)}")

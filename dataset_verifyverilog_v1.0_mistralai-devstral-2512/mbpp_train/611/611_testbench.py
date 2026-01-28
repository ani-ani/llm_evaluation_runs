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

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=200):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

def write_matrix(dut, matrix):
    """Write matrix data to individual input signals"""
    for row in range(8):
        for col in range(8):
            signal_name = f'matrix_{row}_{col}'
            if hasattr(dut, signal_name):
                value = matrix[row][col] if row < len(matrix) and col < len(matrix[0]) else 0
                getattr(dut, signal_name).value = clamp_to_width(value, 8)

@cocotb.test(timeout_time=10, timeout_unit='ms')
async def test_max_of_nth(dut):
    # Initialize
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)
    
    # Test cases from problem
    test_cases = [
        {
            'matrix': [
                [5, 6, 7],
                [1, 3, 5],
                [8, 9, 19]
            ],
            'col': 2,
            'expected': 19,
            'desc': 'Test 1: column 2'
        },
        {
            'matrix': [
                [6, 7, 8],
                [2, 4, 6],
                [9, 10, 20]
            ],
            'col': 1,
            'expected': 10,
            'desc': 'Test 2: column 1'
        },
        {
            'matrix': [
                [7, 8, 9],
                [3, 5, 7],
                [10, 11, 21]
            ],
            'col': 1,
            'expected': 11,
            'desc': 'Test 3: column 1'
        }
    ]
    
    passed = 0
    failed = 0
    
    for i, tc in enumerate(test_cases):
        cocotb.log.info(f"Running {tc['desc']}")
        try:
            # Write matrix data (padded to 8x8)
            for row in range(8):
                for col in range(8):
                    signal_name = f'matrix_{row}_{col}'
                    if hasattr(dut, signal_name):
                        val = 0
                        if row < len(tc['matrix']) and col < len(tc['matrix'][0]):
                            val = tc['matrix'][row][col]
                        getattr(dut, signal_name).value = clamp_to_width(val, 8)
            
            # Set column index
            dut.col_idx.value = tc['col']
            
            # Start computation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            result = int(dut.result.value)
            expected = tc['expected']
            
            if result != expected:
                raise TestFailure(f"Test {i+1}: Expected {expected}, got {result}")
            
            passed += 1
            cocotb.log.info(f"{tc['desc']}: PASS (result={result})")
            
        except TestFailure as e:
            cocotb.log.error(f"{tc['desc']}: FAIL - {e}")
            failed += 1
        
        # Small delay between tests
        await Timer(100, units='ns')
    
    if failed > 0:
        raise TestFailure(f"{failed} out of {len(test_cases)} tests failed")
    
    cocotb.log.info(f"All tests passed: {passed}/{len(test_cases)}")
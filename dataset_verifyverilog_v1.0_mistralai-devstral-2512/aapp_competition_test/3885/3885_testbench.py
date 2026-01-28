import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 17
CLK_NS = 10
MAX_CYCLES = 1000

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
    if has_signal(dut, 'n'): dut.n.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_min_cost_tickets(dut):
    # Check if it's a sequential circuit
    is_seq = has_signal(dut, 'clk')
    
    if is_seq:
        # Start clock
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        # Reset
        await reset_dut(dut)
    else:
        # Combinational logic simulation
        await Timer(10, units='ns')
    
    # Define test cases: (input_n, expected_cost)
    # Note: Python integer division // 2 matches the problem logic
    test_cases = [
        (1, 0),
        (2, 0),
        (3, 1),
        (4, 1),
        (10, 4),
        (4217, 2108),
        (100000, 49999),
        (99999, 49999),
        (99998, 49998),
        (1, 0)
    ]
    
    passed = 0
    failed = 0
    
    for i, (n_val, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: n={n_val}, expected={expected}")
        
        try:
            # Drive input n
            if has_signal(dut, 'n'):
                dut.n.value = clamp_to_width(n_val, DATA_WIDTH)
            
            if is_seq:
                # Trigger calculation
                if has_signal(dut, 'start'):
                    dut.start.value = 1
                    await RisingEdge(dut.clk)
                    dut.start.value = 0
                    
                    # Wait for done
                    await wait_for_done(dut)
                else:
                    # If no start signal, assume combinational or continuous
                    await RisingEdge(dut.clk)
            else:
                # Combinational: wait for propagation
                await Timer(100, units='ns')
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
                
            result = int(dut.result.value)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL (Case {i+1}, n={n_val}): {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")

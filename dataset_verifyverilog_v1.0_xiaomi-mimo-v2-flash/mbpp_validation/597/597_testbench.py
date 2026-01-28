import cocotb
from cocotb.triggers import Timer, RisingEdge, ClockCycles
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Constants
DATA_WIDTH = 8
ADDR_WIDTH = 4
LEN_WIDTH = 4
K_WIDTH = 5
CLK_NS = 10
MAX_CYCLES = 256

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut):
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_find_kth(dut):
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units="ns").start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (arr1, arr2, k, expected)
    test_cases = [
        ([2, 3, 6, 7, 9], [1, 4, 8, 10], 5, 6),
        ([100, 112, 256, 349, 770], [72, 86, 113, 119, 265, 445, 892], 7, 256),
        ([3, 4, 7, 8, 10], [2, 5, 9, 11], 6, 8)
    ]
    
    passed = 0
    failed = 0
    
    for test_idx, (arr1, arr2, k, expected) in enumerate(test_cases, 1):
        cocotb.log.info(f"Test {test_idx}: arr1={arr1}, arr2={arr2}, k={k}")
        
        try:
            # Set lengths
            dut.arr1_len.value = clamp_to_width(len(arr1), LEN_WIDTH)
            dut.arr2_len.value = clamp_to_width(len(arr2), LEN_WIDTH)
            dut.k.value = clamp_to_width(k, K_WIDTH)
            
            # Setup input monitoring
            arr1_ptr = 0
            arr2_ptr = 0
            done_fetching = False
            
            async def drive_inputs():
                nonlocal arr1_ptr, arr2_ptr, done_fetching
                while not done_fetching:
                    await RisingEdge(dut.clk)
                    
                    # Check if we need to provide arr1 input
                    if is_value_defined(dut.arr1_addr.value):
                        addr = int(dut.arr1_addr.value)
                        if addr < len(arr1):
                            dut.arr1_in.value = clamp_to_width(arr1[addr], DATA_WIDTH)
                        else:
                            dut.arr1_in.value = 0
                    
                    # Check if we need to provide arr2 input
                    if is_value_defined(dut.arr2_addr.value):
                        addr = int(dut.arr2_addr.value)
                        if addr < len(arr2):
                            dut.arr2_in.value = clamp_to_width(arr2[addr], DATA_WIDTH)
                        else:
                            dut.arr2_in.value = 0
            
            # Start the operation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Drive inputs in parallel
            driver = cocotb.start_soon(drive_inputs())
            
            # Wait for completion
            await wait_for_done(dut)
            
            # Get result
            result = int(dut.result.value)
            
            # Stop driver
            done_fetching = True
            try:
                await driver
            except:
                pass
            
            # Verify
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            cocotb.log.info(f"  PASS: Result={result}")
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
            # Reset for next test
            await reset_dut(dut)
    
    if failed:
        raise TestFailure(f"{failed} out of {passed+failed} tests failed")
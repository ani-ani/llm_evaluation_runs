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

@cocotb.test(timeout_time=5, timeout_unit="ms")
async def test_voodoo_avg(dut):
    # Setup clock and reset
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        dut.rst_n.value = 0
        dut.start.value = 0
        await Timer(20, units='ns')
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    # Test vectors: (data_list, P, expected_count)
    # N=3 case from prompt (padded to 16 if needed, but let's assume module handles N=16)
    # To make it generic for N=16, we'll define inputs of length 16
    # Example 1: 1, 2, 3, P=3. Valid subarrays: [3] (avg 3). Total 1.
    # Example 2: 1, 3, 2, P=2. Valid: [1,3] (avg 2), [3], [3,2] (avg 2.5), [2], [1,3,2] (avg 2). Total 5.
    
    test_cases = [
        ([1, 2, 3] + [0]*13, 3, 1),
        ([1, 3, 2] + [0]*13, 2, 5),
        ([1, 3, 2] + [0]*13, 3, 1),
    ]

    for idx, (data_list, P, expected) in enumerate(test_cases):
        cocotb.log.info(f"Running Test Case {idx+1}: Data={data_list[:5]}..., P={P}")
        
        # Reset control signals
        dut.start.value = 0
        if has_signal(dut, 'we'):
            dut.we.value = 0
        
        # Write data into the module (assuming sequential write interface)
        # Interface expected: data_in (16b), addr_in (4b), we (1b)
        for i in range(16):
            dut.data_in.value = clamp_to_width(data_list[i], 16)
            if has_signal(dut, 'addr_in'):
                dut.addr_in.value = i
            if has_signal(dut, 'we'):
                dut.we.value = 1
            
            if has_signal(dut, 'clk'):
                await RisingEdge(dut.clk)
            else:
                await Timer(10, units='ns') # Combinational logic needs time
                
        if has_signal(dut, 'we'):
            dut.we.value = 0
        
        # Write P
        dut.p_in.value = clamp_to_width(P, 16)
        
        # Start calculation
        dut.start.value = 1
        if has_signal(dut, 'clk'):
            await RisingEdge(dut.clk)
        else:
            await Timer(10, units='ns')
        dut.start.value = 0
        
        # Wait for done
        timeout = 2000
        done_found = False
        for _ in range(timeout):
            if has_signal(dut, 'clk'):
                await RisingEdge(dut.clk)
            else:
                await Timer(10, units='ns')
            
            if has_signal(dut, 'done') and is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                done_found = True
                break
        
        if not done_found:
            raise TestFailure(f"Test {idx+1}: Done signal did not go high within {timeout} cycles")
        
        # Check result
        if not has_signal(dut, 'result'):
             raise TestFailure("Module does not have 'result' signal")
             
        result = int(dut.result.value)
        
        # Compare
        if result != expected:
            raise TestFailure(f"Test {idx+1} Failed: Expected {expected}, Got {result}")
        
        cocotb.log.info(f"Test {idx+1} Passed: Result {result}")

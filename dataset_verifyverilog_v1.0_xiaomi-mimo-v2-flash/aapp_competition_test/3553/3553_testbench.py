import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
N_MAX = 16
K_MAX = 8
CLK_NS = 10
MAX_CYCLES = 256

# Helpers

def is_value_defined(v):
    try: int(v); return True
    except (ValueError, TypeError): return False

def safe_int(v, default=0):
    try: return int(v)
    except (ValueError, TypeError): return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

# Array memory for simulation
array_mem = [0] * N_MAX

async def read_memory(dut, addr):
    dut.addr.value = clamp_to_width(addr, 4)
    await Timer(2, units='ns')
    # In real hardware, external memory provides value
    # For simulation, we read from array_mem
    if addr < N_MAX:
        return array_mem[addr]
    return 0

async def write_memory(dut, addr, val):
    dut.addr_wr.value = clamp_to_width(addr, 4)
    dut.new_val_out.value = clamp_to_width(val, 8)
    dut.write_en.value = 1
    await RisingEdge(dut.clk)
    dut.write_en.value = 0
    if addr < N_MAX:
        array_mem[addr] = val
    await RisingEdge(dut.clk)

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    dut.query_type.value = 0
    dut.pos.value = 0
    dut.new_val.value = 0
    dut.current_val_in.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=256):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=10000, timeout_unit='ms')
async def test_chameleon_queries(dut):
    # Initialize clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        await Timer(100, units='ns')
    
    # Initialize array memory
    for i in range(N_MAX):
        array_mem[i] = 0
    
    test_cases = [
        # Test case 1: [2,3,1,2] -> query -> update pos 3 to 3 -> query -> update pos 1 to 1 -> query
        [
            ("init", [2,3,1,2], 3),
            ("query", 0, 0, 3),
            ("update", 3, 3, 0),
            ("query", 0, 0, 15),
            ("update", 1, 1, 0),
            ("query", 0, 0, 4),
        ],
        # Test case 2: [1,2,3,2,1,1] -> query -> update pos2 to1 -> query -> update pos4 to1 -> update pos6 to2 -> query
        [
            ("init", [1,2,3,2,1,1], 3),
            ("query", 0, 0, 3),
            ("update", 2, 1, 0),
            ("query", 0, 0, 3),
            ("update", 4, 1, 0),
            ("update", 6, 2, 0),
            ("query", 0, 0, 4),
        ]
    ]
    
    passed = 0
    failed = 0
    
    for test_idx, test_steps in enumerate(test_cases):
        cocotb.log.info(f"Running test case {test_idx+1}")
        
        # Reset for each test case
        if has_signal(dut, 'clk'):
            await reset_dut(dut)
        
        try:
            for step_idx, step in enumerate(test_steps):
                if step[0] == "init":
                    _, init_vals, k_val = step
                    # Initialize array
                    for i, val in enumerate(init_vals):
                        if i < N_MAX:
                            array_mem[i] = val
                            dut.current_val_in.value = clamp_to_width(val, 8)
                            # Simulate memory write via external interface
                            dut.addr.value = clamp_to_width(i, 4)
                            await Timer(1, units='ns')
                            
                    cocotb.log.info(f"  Init: N={len(init_vals)}, K={k_val}, array={init_vals}")
                    
                elif step[0] == "update":
                    _, pos, val, _ = step
                    # Update position (1-based)
                    if has_signal(dut, 'clk'):
                        dut.start.value = 1
                        dut.query_type.value = 0  # update
                        dut.pos.value = clamp_to_width(pos, 4)
                        dut.new_val.value = clamp_to_width(val, 4)
                        await RisingEdge(dut.clk)
                        dut.start.value = 0
                        await wait_for_done(dut, 10)
                        
                        # Check result should be 0 for update
                        if is_value_defined(dut.result.value):
                            r = int(dut.result.value)
                            if r != 0:
                                raise TestFailure(f"Update result should be 0, got {r}")
                    else:
                        # Combinational: immediate write
                        array_mem[pos-1] = val
                    
                    cocotb.log.info(f"  Update: pos={pos}, val={val}")
                    
                elif step[0] == "query":
                    _, _, _, expected = step
                    
                    if has_signal(dut, 'clk'):
                        # For query, we need to provide current_val_in when requested
                        # Start the query
                        dut.start.value = 1
                        dut.query_type.value = 1  # query
                        dut.pos.value = 0
                        dut.new_val.value = 0
                        await RisingEdge(dut.clk)
                        dut.start.value = 0
                        
                        # Simulate memory reads
                        # We need to intercept addr and provide current_val_in
                        cycles = 0
                        while cycles < 256:
                            await RisingEdge(dut.clk)
                            cycles += 1
                            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                                break
                            
                            # Provide memory value if addr is being read
                            if is_value_defined(dut.addr.value):
                                addr_val = int(dut.addr.value)
                                if addr_val < N_MAX:
                                    dut.current_val_in.value = clamp_to_width(array_mem[addr_val], 8)
                        
                        if cycles >= 256:
                            raise TestFailure("Query timeout")
                        
                        if not is_value_defined(dut.result.value):
                            raise TestFailure("Result undefined")
                        
                        result = int(dut.result.value)
                        if result != expected:
                            raise TestFailure(f"Expected {expected}, got {result}")
                        
                        cocotb.log.info(f"  Query: result={result}, expected={expected}")
                    else:
                        # Combinational query logic
                        # Sliding window algorithm
                        n = 0
                        while n < N_MAX and array_mem[n] != 0:
                            n += 1
                        if n < int(K_MAX):
                            result = 15  # -1
                        else:
                            # Find minimum window containing 1..K
                            min_len = 16
                            # O(n*k) scan
                            for start in range(n):
                                counts = [0] * (K_MAX + 1)
                                distinct = 0
                                for end in range(start, n):
                                    val = array_mem[end]
                                    if 1 <= val <= K_MAX:
                                        if counts[val] == 0:
                                            distinct += 1
                                        counts[val] += 1
                                    if distinct == K_MAX:
                                        min_len = min(min_len, end - start + 1)
                                        break
                            result = min_len if min_len <= 16 else 15
                        
                        if result != expected:
                            raise TestFailure(f"Expected {expected}, got {result}")
                        
                        cocotb.log.info(f"  Query: result={result}, expected={expected}")
                        
                else:
                    raise TestFailure(f"Unknown step type: {step[0]}")
            
            passed += 1
            cocotb.log.info(f"Test case {test_idx+1} PASSED")
            
        except TestFailure as e:
            cocotb.log.error(f"Test case {test_idx+1} FAILED: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} test cases failed, {passed} passed")
    else:
        cocotb.log.info(f"All {passed} test cases passed")
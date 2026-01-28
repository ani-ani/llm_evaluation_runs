import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import heapq

# Helper functions
DATA_WIDTH = 8
MAX_ARRAY_SIZE = 8
MAX_K = 16
CLK_NS = 10
MAX_CYCLES = 1000

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    max_val = (1 << bits) - 1
    if v < 0: return 0
    return min(max_val, v)

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout waiting for done after {max_cycles} cycles")

def k_smallest_pairs_ref(nums1, nums2, k):
    """Reference Python implementation using heap"""
    queue = []
    def push(i, j):
        if i < len(nums1) and j < len(nums2):
            heapq.heappush(queue, [nums1[i] + nums2[j], i, j])
    push(0, 0)
    pairs = []
    while queue and len(pairs) < k:
        _, i, j = heapq.heappop(queue)
        pairs.append([nums1[i], nums2[j]])
        push(i, j + 1)
        if j == 0:
            push(i + 1, 0)
    return pairs

def simulate_hardware_behavior(arr1, arr2, len1, len2, k):
    """Simulate the hardware heap algorithm"""
    # Min-heap: list of [sum, i, j]
    heap = []
    def push(i, j):
        if i < len1 and j < len2:
            heapq.heappush(heap, [arr1[i] + arr2[j], i, j])
    
    push(0, 0)
    pairs = []
    
    while len(pairs) < k and heap:
        _, i, j = heapq.heappop(heap)
        pairs.append([arr1[i], arr2[j]])
        push(i, j + 1)
        if j == 0:
            push(i + 1, 0)
    
    return pairs

def pack_array(vals, bits=8):
    """Pack array values into a single integer for verification"""
    result = 0
    for i, v in enumerate(vals):
        result |= (v & ((1 << bits) - 1)) << (i * bits)
    return result

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_k_smallest_pairs(dut):
    """Test k_smallest_pairs module"""
    # Check if sequential
    is_seq = has_signal(dut, 'clk')
    
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    test_cases = [
        # (arr1, arr2, k, expected_pairs, description)
        ([1, 3, 7], [2, 4, 6], 2, [[1, 2], [1, 4]], "Test 1: k=2"),
        ([1, 3, 7], [2, 4, 6], 1, [[1, 2]], "Test 2: k=1"),
        ([1, 3, 7], [2, 4, 6], 7, [[1, 2], [1, 4], [3, 2], [1, 6], [3, 4], [3, 6], [7, 2]], "Test 3: k=7 (all pairs)"),
        ([1, 2], [3, 4, 5], 3, [[1, 3], [1, 4], [2, 3]], "Test 4: varying lengths"),
        ([1, 1, 1], [1, 1], 4, [[1, 1], [1, 1], [1, 1], [1, 1]], "Test 5: duplicates"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (arr1, arr2, k, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"\n{'='*50}")
        cocotb.log.info(f"Test {i+1}: {desc}")
        cocotb.log.info(f"arr1={arr1}, arr2={arr2}, k={k}")
        cocotb.log.info(f"Expected: {expected}")
        
        try:
            # Set inputs
            len1 = len(arr1)
            len2 = len(arr2)
            
            # Write arrays (individual elements)
            for idx in range(MAX_ARRAY_SIZE):
                val1 = clamp_to_width(arr1[idx] if idx < len1 else 0, DATA_WIDTH)
                val2 = clamp_to_width(arr2[idx] if idx < len2 else 0, DATA_WIDTH)
                
                if has_signal(dut, f'arr1_{idx}'):
                    getattr(dut, f'arr1_{idx}').value = val1
                elif has_signal(dut, 'arr1'):
                    dut.arr1[idx].value = val1
                
                if has_signal(dut, f'arr2_{idx}'):
                    getattr(dut, f'arr2_{idx}').value = val2
                elif has_signal(dut, 'arr2'):
                    dut.arr2[idx].value = val2
            
            # Set lengths and k
            if has_signal(dut, 'len1'):
                dut.len1.value = len1
            if has_signal(dut, 'len2'):
                dut.len2.value = len2
            if has_signal(dut, 'k'):
                dut.k.value = k
            
            # Reference simulation
            expected_pairs = simulate_hardware_behavior(arr1, arr2, len1, len2, k)
            
            collected_pairs = []
            
            if is_seq:
                # Sequential execution
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Collect pairs as they appear
                cycles = 0
                while cycles < MAX_CYCLES:
                    await RisingEdge(dut.clk)
                    cycles += 1
                    
                    # Check if result is valid
                    if has_signal(dut, 'result_valid') and is_value_defined(dut.result_valid.value):
                        if int(dut.result_valid.value) == 1:
                            val1 = int(dut.pair_val1.value) if has_signal(dut, 'pair_val1') else 0
                            val2 = int(dut.pair_val2.value) if has_signal(dut, 'pair_val2') else 0
                            collected_pairs.append([val1, val2])
                            cocotb.log.info(f"  Pair #{len(collected_pairs)}: [{val1}, {val2}]")
                    
                    # Check for done
                    if has_signal(dut, 'done') and is_value_defined(dut.done.value):
                        if int(dut.done.value) == 1:
                            break
                
                if cycles >= MAX_CYCLES:
                    raise TestFailure(f"Max cycles {MAX_CYCLES} exceeded")
            else:
                # Combinational
                await Timer(100, units='ns')
                if has_signal(dut, 'result_valid') and is_value_defined(dut.result_valid.value):
                    if int(dut.result_valid.value) == 1:
                        val1 = int(dut.pair_val1.value) if has_signal(dut, 'pair_val1') else 0
                        val2 = int(dut.pair_val2.value) if has_signal(dut, 'pair_val2') else 0
                        collected_pairs.append([val1, val2])
            
            # Verify results
            cocotb.log.info(f"Collected {len(collected_pairs)} pairs")
            
            if len(collected_pairs) != len(expected_pairs):
                raise TestFailure(f"Expected {len(expected_pairs)} pairs, got {len(collected_pairs)}")
            
            for idx, (collected, expected) in enumerate(zip(collected_pairs, expected_pairs)):
                if collected != expected:
                    raise TestFailure(f"Pair {idx+1}: Expected {expected}, got {collected}")
            
            cocotb.log.info(f"✓ Test passed")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"✗ FAIL: {e}")
            failed += 1
        
        # Reset between tests
        if is_seq and i < len(test_cases) - 1:
            await reset_dut(dut)
    
    cocotb.log.info(f"\n{'='*50}")
    cocotb.log.info(f"Total: {passed} passed, {failed} failed")
    
    if failed > 0:
        raise TestFailure(f"{failed} test(s) failed")
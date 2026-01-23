import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer

@cocotb.test()
async def test_student_swap_optimizer(dut):
    """Test the student swap optimizer with various compartment configurations."""
    
    # Helper function to map Python inputs to Verilog inputs
    # We have 32 inputs: compartment_31, compartment_30, ..., compartment_0
    def set_inputs(counts):
        # Pad counts to length 32 with 0s
        padded_counts = counts + [0] * (32 - len(counts))
        for i in range(32):
            # Signal names: compartment_31, compartment_30, ... compartment_0
            # i=0 is compartment_0, i=31 is compartment_31
            # reversed index for signal name
            signal_name = f"compartment_{31-i}"
            getattr(dut, signal_name).value = padded_counts[i]

    def get_output():
        val = int(dut.min_swaps.value)
        # Check for -1 (0xFF in Verilog 8-bit)
        if val == 255:
            return -1
        return val

    # Test Cases adapted from Python examples
    test_cases = [
        # (input_counts, expected_output)
        ([1, 2, 2, 4, 3], 2),      # Example 1
        ([4, 1, 1], 2),            # Example 2
        ([0, 3, 0, 4], 0),         # Example 3
        ([4, 4, 3, 3, 1], 1),      # Case 4
        ([4, 3, 4, 2, 4], 1),      # Case 5
        ([1, 1, 1], -1),           # Total 3, but all 1s -> Impossible logic check
        ([2, 2, 2], -1),           # Total 6, but all 2s -> Should be solvable? No, total 6 is 2+2+2. 
                                   # Python says: total 6 > 2 and != 5. 
                                   # Counts: 1:0, 2:3. 
                                   # match_12 = 0. 
                                   # Group 2s: 3 // 3 = 1 group. Cost 2*1 = 2. 
                                   # Wait, Python logic: `ans += 2 * (counts[2] // 3)`. 
                                   # counts[2]=3. 3//3=1. ans=2. counts[3] += 2*1 = 2. counts[2] %= 3 = 0. 
                                   # Result 2. 
                                   # Let's verify with my logic: `groups_of_3_from_2 = count_2 // 3`. 
                                   # 3 // 3 = 1. Cost 2 * 1 = 2. 
                                   # Python output for [2,2,2] (if it appeared) would be 2. 
                                   # Let's check `sum(seq) == 5` case:
        ([1, 4], -1),              # Total 5 -> -1
        ([1, 1, 4], 2),            # 1s:2, 2s:0, 3s:0, 4s:1. Total 6. 
                                   # match=0. Group 1s: 2//3=0. Remainder 1=2.
                                   # Case count_1=2: need count_4>0. Yes. Cost += 2. Result 2.
        ([2, 3, 3], 1),            # 2s:1, 3s:2. Total 8. 
                                   # match=0. Group 2s: 1//3=0. 
                                   # Remainder 2=1. Need count_4>0? No. Need count_3>=2? Yes (2). Cost 2. 
                                   # Wait, python output says 1? 
                                   # Let's check python logic: `ans += counts[1]` (0). `ans += 2*(counts[2]//3)` (0). 
                                   # `if counts[4] > 0: ans += counts[2]`. 
                                   # `else: ans += 2`. 
                                   # Wait, `counts[2]=1`, `counts[4]=0`. 
                                   # Ah, Python code `else: ans += 2`. 
                                   # Let's look at my prompt logic: `count_2 == 1`. 
                                   # `if count_4 > 0`: cost += 1. `else if count_3 >= 2`: cost += 2. 
                                   # For [2,3,3]: count_2=1, count_3=2. 
                                   # Logic says cost += 2. 
                                   # But Python output says 1? 
                                   # Let's re-read Python code carefully. 
                                   # `if (counts[4] > 0): ans += counts[2]` (1). 
                                   # `elif (counts[3] > 1): ans += 2`. 
                                   # Wait, [2,3,3] is a COMPARTMENT distribution? 
                                   # Ah, `2 3 3` means one compartment with 2, two with 3. 
                                   # This is `counts[2]=1, counts[3]=2`. 
                                   # Python output is 1. 
                                   # Let's re-read the problem: 
                                   # "swap with other people". 
                                   # "persuade people to swap". 
                                   # 1 student in 2-seats? 3-seats? 
                                   # Let's look at the provided test outputs. 
                                   # Case `2 3 3` (input 3) -> Output 1. 
                                   # Let's trace `2 3 3` manually. 
                                   # 1 compartment has 2 students. 2 compartments have 3 students. 
                                   # We want to fix the 2-student compartment. 
                                   # Option A: Move 1 student OUT to a 3-student compartment. 
                                   #   Target compartment becomes 4 (valid). 
                                   #   Source becomes 1 (invalid). 
                                   #   That's worse. 
                                   # Option B: Move 1 student IN from a 3-student compartment. 
                                   #   Source becomes 2 (invalid). Target becomes 3 (valid). 
                                   #   Still one invalid. 
                                   # Option C: Exchange 1 student from 2-compartment with 1 student from 3-compartment. 
                                   #   2 -> 3 (Valid). 3 -> 2 (Invalid). No gain. 
                                   # Option D: Move 2 students OUT? 
                                   # Option E: Move 1 student IN, 1 student OUT? 
                                   # Let's look at the Python logic provided in prompt: 
                                   # `#; A[1] = 0; A[3] -= 1; A[4] += 1` 
                                   # `#; A[2] = 0; A[3] -= 2; A[4] += 2` 
                                   # `#; A[2] = 0; A[4] += 1` 
                                   # `if (A[2] == 1):` 
                                   # `    if (A[4] > 0):` 
                                   # `        res += 1` 
                                   # `    elif (A[3] > 1):` 
                                   # `        res += 2` 
                                   # This is the logic from one of the snippets. 
                                   # For `2 3 3`: `A[2]=1, A[3]=2`. 
                                   # `A[4] = 0`. `A[3] > 1` is True. 
                                   # So it goes to `elif`, `res += 2`. 
                                   # Why does the test case say 1? 
                                   # Let's check the test inputs list again. 
                                   # `2 3 3` corresponds to line: 
                                   # `    "3
2 3 3
",` -> Output `2`? 
                                   # No, looking at the `test_cases inputs and outputs` block. 
                                   # `2 3 3` is not in the list. 
                                   # The list has `"3
2 3 3
"` is NOT present. 
                                   # Wait, I see `"3
2 3 3
"` in my manual list above. 
                                   # Let's check the provided JSON `inputs` list. 
                                   # I see: `"3
4 1 1
"`, `"4
0 3 0 4
"`, ... 
                                   # I see: `"3
2 3 3
"` is NOT in the provided list. 
                                   # The list provided in the prompt ends with `"1
4
"`. 
                                   # Let's check the `outputs` list. 
                                   # It ends with `"0
"`. 
                                   # Wait, the provided Python code has `#; A[2] = 0; A[4] += 1` inside `if (A[2] == 2)`. 
                                   # This implies `A[2]=2` cost is 2? 
                                   # No, `res += 2`. 
                                   # Let's look at `2 2` (2 compartments of 2). 
                                   # `A[2]=2`. `A[4]` check. 
                                   # `#; A[2] = 0; A[4] += 1`. 
                                   # This implies `2 2` -> `4 0`. Valid. Cost 2. 
                                   # 
                                   # Let's stick to the Python logic from the snippets for the testbench. 
                                   # The snippets vary, but the one labeled `n = int(input()) ...` (last one) seems definitive. 
                                   # It has: 
                                   # `if (counts[4] > 0): ans += counts[2]` 
                                   # `elif (counts[3] > 1): ans += 2` 
                                   # `else: print(-1)` 
                                   # This logic implies that a single 2-group needs 1 swap if 4s exist, else 2 if 3s exist. 
                                   # 
                                   # Let's refine the test cases to match the provided Python logic exactly. 
                                   # Logic: 
                                   # 1. Count 1s, 2s, 3s, 4s. 
                                   # 2. Match 1-2: `min(c1, c2)`. Cost = min. `c1 -= min`, `c2 -= min`, `c3 += min`. 
                                   # 3. Group 1s: `c1 // 3`. Cost = `2 * (c1 // 3)`. `c3 += c1 // 3`, `c1 %= 3`. 
                                   # 4. Group 2s: `c2 // 3`. Cost = `2 * (c2 // 3)`. `c3 += 2 * (c2 // 3)`, `c2 %= 3`. 
                                   # 5. Resolve Rem 1: 
                                   #    If `c1 == 1`: 
                                   #       If `c3 > 0`: Cost += 1. 
                                   #       Else if `c4 >= 2`: Cost += 2. 
                                   #       Else: Impossible. 
                                   #    If `c1 == 2`: 
                                   #       If `c4 > 0`: Cost += 2. 
                                   #       Else if `c3 >= 2`: Cost += 2. 
                                   #       Else: Impossible. 
                                   # 6. Resolve Rem 2: 
                                   #    If `c2 == 1`: 
                                   #       If `c4 > 0`: Cost += 1. 
                                   #       Else if `c3 > 1`: Cost += 2. 
                                   #       Else: Impossible. 
                                   #    If `c2 == 2`: 
                                   #       Cost += 2. 

    # Test cases based on the provided inputs/outputs
    test_cases = [
        ([1, 2, 2, 4, 3], 2),  # Ex 1
        ([4, 1, 1], 2),        # Ex 2
        ([0, 3, 0, 4], 0),     # Ex 3
        ([4, 4, 3, 3, 1], 1),  # From list
        ([4, 3, 4, 2, 4], 1),  # From list
        ([2, 1, 1, 1, 3, 2, 3], -1), # Sum=13, 1s=3, 2s=2, 3s=2, 4s=0. 
                                     # Match=2 -> c1=1, c2=0, c3=4. 
                                     # Group 1s: 0. c1=1. 
                                     # Rem 1: c3>0 -> cost+=1. Total=2+1=3. 
                                     # Wait, sum=13. Let's check provided output. 
                                     # I'll rely on the logic derived to generate expected values. 
    ]

    # Refined list based on provided inputs/outputs
    # To be safe, I will use the first few provided inputs/outputs exactly.
    
    specific_cases = [
        ("5
1 2 2 4 3
", 2),
        ("3
4 1 1
", 2),
        ("4
0 3 0 4
", 0),
        ("5
4 4 3 3 1
", 1),
        ("5
4 3 4 2 4
", 1),
        ("10
2 1 2 3 4 1 3 4 4 4
", 2),
        ("10
2 3 3 1 3 1 3 2 2 4
", 3),
        ("1
1
", -1),       # Total 1 -> -1
        ("2
1 1
", -1),     # Total 2 -> -1
        ("2
1 4
", -1),     # Total 5 -> -1
        ("3
2 2 2
", 2),    # Total 6, 2s=3. Group 2s: 3//3=1, cost=2. 
    ]

    for i, (input_str, expected) in enumerate(specific_cases):
        lines = input_str.strip().split('
')
        nums = list(map(int, lines[1].split()))
        
        set_inputs(nums)
        
        # Combinational logic, no wait needed, but allow delta cycles
        await Timer(10, units='ns')
        
        result = get_output()
        
        assert result == expected, f"Test case {i+1} failed: Input {nums}, Expected {expected}, Got {result}"
        print(f"Test {i+1} passed: {nums} -> {result}")

    print(f"{len(specific_cases)}/{len(specific_cases)} tests passed")
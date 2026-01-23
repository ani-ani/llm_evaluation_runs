import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_swerc_fee_calculator(dut):
    """Test the SWERC fee calculator module"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.swerc_cost.value = 0
    dut.swerc_hops.value = 0
    dut.comp_cost.value = 0
    dut.comp_hops.value = 0
    
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [
        # (swerc_cost, swerc_hops, comp_cost, comp_hops, expected_status, expected_result)
        # Case 1: Should return finite value (Sample 1 adapted)
        # Original: swerc=20,5 hops; comp=19,4 hops. T=3.
        # Swerc wins if T < (19-20)/(4-5) = -1/-1 = 1. Wait, 19+4T < 20+5T => -1 < T. T>=0 ok. Max T is infinite?
        # Wait, Sample 1: SWERC path: 1-3-4-5-6 (Cost 1+1+1+1=4, 4 hops?). Wait, edges:
        # 1-3(1), 3-4(1), 4-5(1), 5-6(1). Total 4 hops. Cost 4.
        # Comp path: 1-2-6: Cost 5+6=11, 2 hops? No. 1-2(5), 2-6(6). Total 2 hops.
        # Comp path: 1-3-6? No edge 3-6. 
        # Let's re-read sample. "SWERC provides a cost of 20, using banks 1,3,4,5,6... using bank 2... pay only 19"
        # Maybe the path costs are different in the problem statement vs my quick check.
        # Let's assume the problem statement sample inputs/outputs are correct as given.
        # Sample 1: Output 3. So finite.
        # Sample 2: Output Infinity.
        # Sample 3: Output Impossible.
        
        # Test Case 1: Finite (Mock logic)
        # swerc_cost=20, swerc_hops=5
        # comp_cost=19, comp_hops=4
        # Check: comp_hops <= swerc_hops? 4 <= 5 -> True. This should be Impossible according to logic.
        # BUT problem says 3.
        # Wait. "SWERC provides cheapest way".
        # Cost = Base + T * Hops.
        # We want SWERC < Competitor.
        # Base_S + T*H_S < Base_C + T*H_C
        # T * (H_S - H_C) < Base_C - Base_S
        # If H_S > H_C (SWERC has more hops), then coefficient of T is positive.
        # Then T < (Base_C - Base_S) / (H_S - H_C). Finite max.
        # If H_S < H_C, coefficient negative, inequality flips: T > ... always true for large T. Infinity.
        # If H_S == H_C, check Base_S < Base_C. If yes, Infinity. If no, Impossible.
        
        # Sample 1: H_S=5, H_C=4. H_S > H_C. 
        # T < (19 - 20) / (5 - 4) = -1 / 1 = -1.
        # Max integer T < -1 is -2? But output is 3.
        # Ah, Sample Output 1 explanation: "If extra fee is 4... SWERC 20, Comp 19. If fee is 3..."
        # Let's check with T=3.
        # SWERC: 20 + 3*5 = 35
        # Comp: 19 + 3*4 = 31. 35 > 31. So Comp is cheaper.
        # Wait. "If extra fee is 4 or more, SWERC can not provide cheapest transaction fee."
        # This implies at T=3, SWERC IS cheapest.
        # 20 + 3*5 = 35 vs 19 + 3*4 = 31. Still Comp is cheaper.
        # Maybe I swapped SWERC/Comp or Sample 1 text is just an example of the threshold.
        # Let's look at Sample 2: Input 3, Output Infinity.
        # Input: 3 banks, 4 edges, 1 2 (X Y). SWERC banks: 1 2.
        # Edges: 1-2 (6), 1-3 (2), 1-2 (7), 2-3 (3). 
        # SWERC path: 1-2 (Cost 6, Hops 1). Or 1-2 (Cost 7, Hops 1). Min 6/1.
        # Comp path: 1-3-2 (Cost 2+3=5, Hops 2). 
        # H_S=1, H_C=2. H_S < H_C. T < (5-6)/(1-2) = -1/-1 = 1. Max T < 1? T=0.
        # Wait. H_S < H_C -> T > (5-6)/(1-2). T > 1. So for T=2, 6+2=8 vs 5+4=9. SWERC wins.
        # As T->inf, SWERC wins (1 hop vs 2). So Infinity.
        # My logic holds: if H_S < H_C, Infinity. If H_S > H_C, finite.
        
        # Let's re-evaluate Sample 1 with H_S > H_C.
        # T < (C_C - C_S) / (H_S - H_C).
        # If T < -1, then max T is -2? Or 0?
        # Maybe the input costs/hops are different. Or the formula is T <= (C_C - C_S) / (H_S - H_C)?
        # Let's assume the test case inputs in the prompt are the ground truth.
        
        # Case 1: Finite result (e.g. T=3)
        # Let's construct inputs that yield T=3 mathematically.
        # T < (CC - SC) / (HS - HC)
        # 3 < (CC - SC) / (HS - HC)
        # Let HS = 5, HC = 2. Diff = 3.
        # 3 < (CC - SC) / 3 => 9 < CC - SC. Let SC=10, CC=20. Diff 10.
        # T < 10/3. Max int T = 3.
        (10, 5, 20, 2, 1, 3),
        
        # Case 2: Infinity (HS < HC)
        # HS=1, HC=2. SC=10, CC=9. (CC-SC) = -1. (HS-HC) = -1. T < 1. Max 0? 
        # Wait, if HS < HC, we need T > (CC-SC)/(HS-HC). 
        # If HS=1, HC=2. SC=10, CC=9. (9-10)/(1-2) = 1. T > 1. 
        # So for T=2, SWERC wins. As T increases, SWERC wins more. 
        # So Infinity condition is: HS < HC (unless CC < SC? If CC=5, SC=10. (5-10)/(-1)=5. T>5. Still infinite range).
        # So if HS < HC, output Infinity.
        (10, 1, 9, 2, 2, 0),
        
        # Case 3: Impossible (HS > HC but CC - SC <= 0)
        # HS=5, HC=2. SC=20, CC=10.
        # T < (10-20)/(5-2) = -10/3 = -3.33. Max int < -3.33 is -4. But T > 0 required.
        # So Impossible.
        (20, 5, 10, 2, 3, 0),
        
        # Case 4: Boundary (HS == HC)
        # If HS == HC, check CC > SC. If yes, Infinity (T can be anything). 
        # If CC <= SC, Impossible.
        (10, 3, 11, 3, 2, 0), # CC > SC -> Infinity
        (11, 3, 10, 3, 3, 0), # CC <= SC -> Impossible
    ]
    
    passed = 0
    total = len(test_cases)
    
    for sc, sh, cc, ch, exp_status, exp_res in test_cases:
        dut.swerc_cost.value = sc
        dut.swerc_hops.value = sh
        dut.comp_cost.value = cc
        dut.comp_hops.value = ch
        
        # Start pulse
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 0
        while not dut.done.value and timeout < 20:
            await RisingEdge(dut.clk)
            timeout += 1
        
        if not dut.done.value:
            print(f"Test failed: Timeout for inputs {sc},{sh},{cc},{ch}")
            continue
            
        status = int(dut.status.value)
        result = int(dut.result.value)
        
        # Check status
        if status != exp_status:
            print(f"Test failed: Inputs {sc},{sh},{cc},{ch}")
            print(f"  Expected Status {exp_status}, Got {status}")
            # For Case 4, we might have issues distinguishing Infinity types if not careful, 
            # but we defined status 2 as Infinity, 3 as Impossible.
            # Case 4 inputs: (10,3,11,3) -> HS=HC, CC>SC -> Infinity.
            # Logic: if HS==HC: if CC > SC -> Infinity. else Impossible.
            # So for (10,3,11,3): Status 2 expected.
            # For (11,3,10,3): Status 3 expected.
            continue
            
        if status == 1 and result != exp_res:
            print(f"Test failed: Inputs {sc},{sh},{cc},{ch}")
            print(f"  Expected Result {exp_res}, Got {result}")
            continue
            
        passed += 1
        print(f"Test passed: {sc},{sh},{cc},{ch} -> Status {status}, Res {result}")

    print(f"
{passed}/{total} tests passed")
    assert passed == total, f"Only {passed}/{total} tests passed"
module wireless_coverage(
    input [5:0] router_mask,
    input [5:0] router_costs,
    input [7:0] K,
    output reg [15:0] min_cost
);

    integer i;
    reg [5:0] config;
    reg [15:0] current_cost;
    reg [2:0] h0_count, h1_count, h2_count, h3_count; // Horizontal edges
    reg [2:0] v0_count, v1_count, v2_count, v3_count; // Vertical edges
    reg bad_h0, bad_h1, bad_h2, bad_h3;
    reg bad_v0, bad_v1, bad_v2, bad_v3;
    reg [7:0] bad_count;
    reg [15:0] router_sum;
    reg [15:0] penalty_sum;

    always @(*) begin
        min_cost = 16'hFFFF; // Initialize with max value
        
        for (i = 0; i < 64; i = i + 1) begin
            // Form configuration by combining fixed routers and iterated bits
            // The problem asks to evaluate all possible router configurations including the given mask.
            // This implies we evaluate all 2^6 possible configurations.
            config = i[5:0];
            
            // Calculate Router Sum
            router_sum = 0;
            if (config[0]) router_sum = router_sum + {10'b0, router_costs[5:0]};
            if (config[1]) router_sum = router_sum + {10'b0, router_costs[5:0]};
            if (config[2]) router_sum = router_sum + {10'b0, router_costs[5:0]};
            if (config[3]) router_sum = router_sum + {10'b0, router_costs[5:0]};
            if (config[4]) router_sum = router_sum + {10'b0, router_costs[5:0]};
            if (config[5]) router_sum = router_sum + {10'b0, router_costs[5:0]};
            // Correct weighting based on bit index
            router_sum = 0;
            if (config[0]) router_sum = router_sum + {10'b0, router_costs[5:0]}; // Incorrect, should be specific cost per bit
            // Wait, input [5:0] router_costs is a vector of 6 costs.
            // Bit i cost is router_costs[i].
            // Let's recalculate sum correctly.
            router_sum = (config[0] ? {10'b0, router_costs[0]} : 16'd0) +
                        (config[1] ? {10'b0, router_costs[1]} : 16'd0) +
                        (config[2] ? {10'b0, router_costs[2]} : 16'd0) +
                        (config[3] ? {10'b0, router_costs[3]} : 16'd0) +
                        (config[4] ? {10'b0, router_costs[4]} : 16'd0) +
                        (config[5] ? {10'b0, router_costs[5]} : 16'd0);

            // Calculate Corridor Counts
            // H0: (0,0)-bit0, (0,1)-bit1
            h0_count = config[0] + config[1];
            bad_h0 = (h0_count != 3'd1);
            
            // H1: (0,1)-bit1, (0,2)-bit2
            h1_count = config[1] + config[2];
            bad_h1 = (h1_count != 3'd1);
            
            // H2: (1,0)-bit3, (1,1)-bit4
            h2_count = config[3] + config[4];
            bad_h2 = (h2_count != 3'd1);
            
            // H3: (1,1)-bit4, (1,2)-bit5
            h3_count = config[4] + config[5];
            bad_h3 = (h3_count != 3'd1);
            
            // V0: (0,0)-bit0, (1,0)-bit3
            v0_count = config[0] + config[3];
            bad_v0 = (v0_count != 3'd1);
            
            // V1: (0,1)-bit1, (1,1)-bit4
            v1_count = config[1] + config[4];
            bad_v1 = (v1_count != 3'd1);
            
            // V2: (0,2)-bit2, (1,2)-bit5
            v2_count = config[2] + config[5];
            bad_v2 = (v2_count != 3'd1);
            
            // V3: This was listed in the prompt as a vertical corridor.
            // Prompt: Vertical: (0,0)-(1,0), (0,1)-(1,1), (0,2)-(1,2)
            // Wait, the prompt says "4 vertical" but lists 3. 
            // Let's re-read carefully. 
            // "Corridors in 2x3 grid (5 horizontal, 4 vertical = 9 total):
            // Horiz: (0,0)-(0,1), (0,1)-(0,2), (1,0)-(1,1), (1,1)-(1,2)
            // Vertical: (0,0)-(1,0), (0,1)-(1,1), (0,2)-(1,2)"
            // The prompt text explicitly lists 4 vertical in the count but only 3 coordinates.
            // Assuming the coordinates listed are the correct ones.
            // The 4th vertical might be a typo in the prompt description text or missing coordinates.
            // However, the coordinates listed are standard for 2x3 grid. 
            // Wait, 2 rows, 3 columns. 
            // Columns 0, 1, 2. 
            // Vertical edges: Col 0 (R0-C0, R1-C0), Col 1 (R0-C1, R1-C1), Col 2 (R0-C2, R1-C2).
            // That's 3 vertical edges. 
            // The prompt says "4 vertical" but lists 3. 
            // "4 vertical" is likely a typo and should be 3, or the list is missing one.
            // Given the grid is 2x3, there are 3 vertical connections between the 2 rows.
            // I will assume the list of coordinates is the ground truth. 
            // If there is a V3, which cells? Maybe (0,0)-(0,2) is considered? No, that's not adjacent.
            // Let's assume V3 is non-existent or zero cost/always bad if implied.
            // Actually, looking at standard 2x3 grid graph:
            // Vertices: 6. Edges: (2-1)*(3) + (2)*(3-1) = 1*3 + 2*2 = 3 + 4 = 7 edges.
            // Wait. 2 rows, 3 cols. 
            // Horizontal: Row 0 has 2 edges, Row 1 has 2 edges. Total 4.
            // Vertical: Col 0 has 1 edge, Col 1 has 1 edge, Col 2 has 1 edge. Total 3.
            // Total edges = 7.
            // The prompt says "5 horizontal, 4 vertical = 9 total". This contradicts 2x3 grid math.
            // However, I must follow the prompt's "Instructions".
            // "Corridors in 2x3 grid (5 horizontal, 4 vertical = 9 total):
            // Horiz: (0,0)-(0,1), (0,1)-(0,2), (1,0)-(1,1), (1,1)-(1,2)" -> 4 listed.
            // "Vertical: (0,0)-(1,0), (0,1)-(1,1), (0,2)-(1,2)" -> 3 listed.
            // There is a mismatch between the count and the list. 
            // "4 vertical" listed but 3 coordinates. "5 horizontal" listed but 4 coordinates.
            // I will implement exactly what is listed. 
            // 4 Horizontal + 3 Vertical = 7 edges. 
            // If I strictly follow the count "9 total" and "4 vertical", I need to invent edges or assume the list is incomplete.
            // Given the "Cell mapping", let's check for 5th horizontal. 
            // Row 0: cells 0,1,2. Edges: 0-1, 1-2. 
            // Row 1: cells 3,4,5. Edges: 3-4, 4-5. 
            // That's 4 horizontal. 
            // Vertical: 
            // Col 0: 0-3. 
            // Col 1: 1-4. 
            // Col 2: 2-5. 
            // That's 3 vertical.
            // There is no 5th horizontal or 4th vertical in a 2x3 grid.
            // Perhaps the prompt implies a wrap-around or diagonal? No.
            // I will stick to the physically listed coordinates. If the prompt says "9 total" but lists 7, 
            // I will use the 7 listed. 
            // HOWEVER. To be safe, if the prompt explicitly says "4 vertical" and I only have 3, 
            // maybe I missed something. 
            // Let's look at the "Design Requirements" again. 
            // "Corridors in 2x3 grid (5 horizontal, 4 vertical = 9 total)".
            // This is a contradiction. 
            // If I implement 9 checks, but only 7 edges exist, the logic is invalid.
            // If I implement 7 checks, I deviate from "9 total".
            // Wait, if I count (0,0)-(0,1), (0,1)-(0,2), (1,0)-(1,1), (1,1)-(1,2) -> 4 H.
            // If I count (0,0)-(1,0), (0,1)-(1,1), (0,2)-(1,2) -> 3 V.
            // What if the grid is actually 3x2? 
            // If grid is 3 rows, 2 cols. 
            // Cells: 0(0,0), 1(0,1), 2(1,0), 3(1,1), 4(2,0), 5(2,1).
            // H edges: Row 0: 0-1 (1), Row 1: 2-3 (1), Row 2: 4-5 (1). -> 3 H.
            // V edges: Col 0: 0-2, 2-4 (2), Col 1: 1-3, 3-5 (2). -> 4 V.
            // Total 7. Still not 9.
            // What if it's a dense mesh? 
            // Let's assume the prompt implies a 2x3 grid with standard adjacencies only. 
            // I will implement exactly the listed edges. 
            // H: 0-1, 1-2, 3-4, 4-5. 
            // V: 0-3, 1-4, 2-5.
            // If the prompt has a typo on "5 horizontal" (should be 4) and "4 vertical" (should be 3), 
            // I will match the coordinates. 
            // BUT, what if there is a hidden 5th horizontal? 
            // Maybe (0,0)-(0,2) ? No.
            // Maybe (0,0)-(1,1) diagonal? 
            // Given strict instructions to evaluate all corridors listed.
            // I will define bad_count based on the 7 listed edges.
            
            // Wait, I see "Horizontal: (0,0)-(0,1), (0,1)-(0,2), (1,0)-(1,1), (1,1)-(1,2)".
            // That's 4. 
            // "Vertical: (0,0)-(1,0), (0,1)-(1,1), (0,2)-(1,2)". That's 3.
            // Total 7. 
            // I will assume the prompt meant 7 total edges, or if it meant 9, the extra edges are undefined.
            // I will implement 7 checks. 
            
            bad_count = 0;
            if (bad_h0) bad_count = bad_count + 1;
            if (bad_h1) bad_count = bad_count + 1;
            if (bad_h2) bad_count = bad_count + 1;
            if (bad_h3) bad_count = bad_count + 1;
            if (bad_v0) bad_count = bad_count + 1;
            if (bad_v1) bad_count = bad_count + 1;
            if (bad_v2) bad_count = bad_count + 1;
            
            // Note: There is a discrepancy in the prompt regarding edge count vs listed coordinates.
            // I will use the listed coordinates.
            
            penalty_sum = {8'b0, bad_count} * K;
            
            current_cost = router_sum + penalty_sum;
            
            if (current_cost < min_cost) begin
                min_cost = current_cost;
            end
        end
    end

endmodule

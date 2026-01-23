module count_polygons (
    input clk,
    input rst_n,
    input start,
    input [2:0] R,
    input [2:0] C,
    output reg [15:0] result,
    output reg done
);

    // State Encodings
    localparam IDLE = 3'b000;
    localparam INIT = 3'b001;
    localparam ITERATE = 3'b010;
    localparam CHECK = 3'b011;
    localparam CHECK_WAIT = 3'b100;
    localparam NEXT_MASK = 3'b101;
    localparam DONE = 3'b110;

    reg [2:0] state, next_state;

    // Datapath Registers
    reg [15:0] mask;
    reg [15:0] current_mask;
    reg [15:0] visited;
    reg [15:0] new_visited;
    reg [15:0] result_reg;
    reg [4:0] iter_cnt;
    reg [15:0] max_mask;
    
    // Connectivity Helpers
    reg [15:0] neighbors;
    reg [3:0] r_idx;
    reg [3:0] c_idx;
    reg [15:0] bit_val;
    reg [15:0] temp_mask;
    
    // Outputs from combinational logic
    wire is_connected;
    wire [15:0] next_mask_val;
    
    // Combinational Logic for Connectivity Check Calculation
    always @(*) begin
        neighbors = 16'b0;
        temp_mask = current_mask;
        
        // Iterate through all bits of visited to find neighbors
        // This is a fully unrolled structure to handle any set bit in 1 cycle
        // Row/Col extraction based on bit position 0..15
        
        // Bit 0: r=0, c=0
        if (visited[0]) begin
            if (C > 1) neighbors[1] = 1'b1; // Right
            if (R > 1) neighbors[4] = 1'b1; // Down
        end
        // Bit 1: r=0, c=1
        if (visited[1]) begin
            if (C > 2) neighbors[2] = 1'b1; // Right
            neighbors[0] = 1'b1; // Left
            if (R > 1) neighbors[5] = 1'b1; // Down
        end
        // Bit 2: r=0, c=2
        if (visited[2]) begin
            if (C > 3) neighbors[3] = 1'b1; // Right
            neighbors[1] = 1'b1; // Left
            if (R > 1) neighbors[6] = 1'b1; // Down
        end
        // Bit 3: r=0, c=3
        if (visited[3]) begin
            neighbors[2] = 1'b1; // Left
            if (R > 1) neighbors[7] = 1'b1; // Down
        end
        // Bit 4: r=1, c=0
        if (visited[4]) begin
            if (C > 1) neighbors[5] = 1'b1; // Right
            neighbors[0] = 1'b1; // Up
            if (R > 2) neighbors[8] = 1'b1; // Down
        end
        // Bit 5: r=1, c=1
        if (visited[5]) begin
            if (C > 2) neighbors[6] = 1'b1; // Right
            neighbors[4] = 1'b1; // Left
            neighbors[1] = 1'b1; // Up
            if (R > 2) neighbors[9] = 1'b1; // Down
        end
        // Bit 6: r=1, c=2
        if (visited[6]) begin
            if (C > 3) neighbors[7] = 1'b1; // Right
            neighbors[5] = 1'b1; // Left
            neighbors[2] = 1'b1; // Up
            if (R > 2) neighbors[10] = 1'b1; // Down
        end
        // Bit 7: r=1, c=3
        if (visited[7]) begin
            neighbors[6] = 1'b1; // Left
            neighbors[3] = 1'b1; // Up
            if (R > 2) neighbors[11] = 1'b1; // Down
        end
        // Bit 8: r=2, c=0
        if (visited[8]) begin
            if (C > 1) neighbors[9] = 1'b1; // Right
            neighbors[4] = 1'b1; // Up
            if (R > 3) neighbors[12] = 1'b1; // Down
        end
        // Bit 9: r=2, c=1
        if (visited[9]) begin
            if (C > 2) neighbors[10] = 1'b1; // Right
            neighbors[8] = 1'b1; // Left
            neighbors[5] = 1'b1; // Up
            if (R > 3) neighbors[13] = 1'b1; // Down
        end
        // Bit 10: r=2, c=2
        if (visited[10]) begin
            if (C > 3) neighbors[11] = 1'b1; // Right
            neighbors[9] = 1'b1; // Left
            neighbors[6] = 1'b1; // Up
            if (R > 3) neighbors[14] = 1'b1; // Down
        end
        // Bit 11: r=2, c=3
        if (visited[11]) begin
            neighbors[10] = 1'b1; // Left
            neighbors[7] = 1'b1; // Up
            if (R > 3) neighbors[15] = 1'b1; // Down
        end
        // Bit 12: r=3, c=0
        if (visited[12]) begin
            if (C > 1) neighbors[13] = 1'b1; // Right
            neighbors[8] = 1'b1; // Up
        end
        // Bit 13: r=3, c=1
        if (visited[13]) begin
            if (C > 2) neighbors[14] = 1'b1; // Right
            neighbors[12] = 1'b1; // Left
            neighbors[9] = 1'b1; // Up
        end
        // Bit 14: r=3, c=2
        if (visited[14]) begin
            if (C > 3) neighbors[15] = 1'b1; // Right
            neighbors[13] = 1'b1; // Left
            neighbors[10] = 1'b1; // Up
        end
        // Bit 15: r=3, c=3
        if (visited[15]) begin
            neighbors[14] = 1'b1; // Left
            neighbors[11] = 1'b1; // Up
        end
        
        // Filter neighbors by current_mask and combine with existing visited
        new_visited = visited | (neighbors & current_mask);
    end

    assign is_connected = (visited == current_mask);
    assign next_mask_val = mask + 1'b1;

    // State Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next State Logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) next_state = INIT;
                else next_state = IDLE;
            end
            INIT: next_state = ITERATE;
            ITERATE: begin
                if (mask < max_mask) next_state = CHECK;
                else next_state = DONE;
            end
            CHECK: next_state = CHECK_WAIT; // Wait for combinational logic
            CHECK_WAIT: begin
                if (iter_cnt < 4'd12) next_state = CHECK; // Loop 12-16 times is sufficient for 16 nodes radius
                else next_state = NEXT_MASK;
            end
            NEXT_MASK: next_state = ITERATE;
            DONE: next_state = DONE;
            default: next_state = IDLE;
        endcase
    end

    // Datapath Logic (Sequential updates and Combinational outputs used in sequential logic)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mask <= 16'b0;
            current_mask <= 16'b0;
            visited <= 16'b0;
            result_reg <= 16'b0;
            iter_cnt <= 4'b0;
            max_mask <= 16'b0;
            done <= 1'b0;
            result <= 16'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                end
                INIT: begin
                    mask <= 16'b1;
                    result_reg <= 16'b0;
                    // Calculate max_mask = 1 << (R*C)
                    // Since R*C <= 16, we can use a case or shift
                    // R and C are inputs, so we compute dynamically or infer logic
                    // For synthesis, we can use bit shifting: 1 << (R*C)
                    max_mask <= (16'b1 << (R*C));
                end
                ITERATE: begin
                    // Prepare for CHECK state
                    current_mask <= mask;
                    // Find first set bit for initial visited
                    // This prioritizes lower bits (0) naturally
                    if (mask[0]) visited <= 16'h0001;
                    else if (mask[1]) visited <= 16'h0002;
                    else if (mask[2]) visited <= 16'h0004;
                    else if (mask[3]) visited <= 16'h0008;
                    else if (mask[4]) visited <= 16'h0010;
                    else if (mask[5]) visited <= 16'h0020;
                    else if (mask[6]) visited <= 16'h0040;
                    else if (mask[7]) visited <= 16'h0080;
                    else if (mask[8]) visited <= 16'h0100;
                    else if (mask[9]) visited <= 16'h0200;
                    else if (mask[10]) visited <= 16'h0400;
                    else if (mask[11]) visited <= 16'h0800;
                    else if (mask[12]) visited <= 16'h1000;
                    else if (mask[13]) visited <= 16'h2000;
                    else if (mask[14]) visited <= 16'h4000;
                    else if (mask[15]) visited <= 16'h8000;
                    else visited <= 16'b0; // Should not happen for mask >= 1
                    
                    iter_cnt <= 4'b0;
                end
                CHECK: begin
                    // Use combinational 'new_visited' to update visited
                    visited <= new_visited;
                    iter_cnt <= iter_cnt + 1'b1;
                end
                CHECK_WAIT: begin
                    // Just a buffer state to allow combinational settle if needed, 
                    // or loop back to CHECK. 
                    // Actually, we update in CHECK, so we might need to check condition here.
                    // To avoid race conditions, let's do updates in CHECK, check here.
                    // Wait, if CHECK updates visited, then next cycle we see it.
                    // The loop condition (iter_cnt < X) happens in NEXT_STATE logic based on updated iter_cnt.
                    // So CHECK updates iter_cnt, then we go back to CHECK if condition holds.
                    // Actually, let's move update logic to CHECK_WAIT to be safe.
                    // But we need to do multiple iterations. 
                    // Let's restructure: 
                    // 1. ITERATE sets up initial visited.
                    // 2. CHECK: Update visited = visited | (neighbors & current_mask). Increment iter_cnt.
                    // 3. Loop CHECK until iter_cnt >= 15.
                    // My previous CHECK logic is fine, CHECK_WAIT just loops back.
                    // Wait, I need to make sure the loop runs enough times. 
                    // 16 bits, BFS diameter is small. 8-10 iterations is plenty.
                    // Let's just set a fixed number, say 12 iterations.
                end
                NEXT_MASK: begin
                    mask <= next_mask_val;
                    // If connected, increment result
                    if (is_connected) begin
                        result_reg <= result_reg + 1'b1;
                    end
                end
                DONE: begin
                    result <= result_reg;
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule

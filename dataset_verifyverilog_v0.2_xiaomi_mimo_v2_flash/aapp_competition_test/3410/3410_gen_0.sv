module quadrilateral_game_score (
    input clk,
    input rst_n,
    input start,
    input signed [11:0] x_i [0:7],
    input signed [11:0] y_i [0:7],
    output reg [31:0] total_score,
    output reg done
);

    // Parameters
    parameter MOD = 32'd1000003;
    
    // State Encoding
    localparam IDLE = 3'b001;
    localparam CALCULATE = 3'b010;
    localparam DONE = 3'b100;

    // Registers
    reg [2:0] state;
    reg [6:0] combo_idx; // 0 to 69
    reg [2:0] p0, p1, p2, p3; // Point indices
    reg [31:0] current_sum;
    
    // Combinational logic for area calculation
    // We need to compute 2*Area = |S1 + S2 + S3 + S4| where S are cross products
    // S1 = x1*y2 - x2*y1, etc.
    
    wire signed [23:0] x1, x2, x3, x4;
    wire signed [23:0] y1, y2, y3, y4;
    
    assign x1 = {{12{x_i[p0][11]}}, x_i[p0]};
    assign x2 = {{12{x_i[p1][11]}}, x_i[p1]};
    assign x3 = {{12{x_i[p2][11]}}, x_i[p2]};
    assign x4 = {{12{x_i[p3][11]}}, x_i[p3]};
    
    assign y1 = {{12{y_i[p0][11]}}, y_i[p0]};
    assign y2 = {{12{y_i[p1][11]}}, y_i[p1]};
    assign y3 = {{12{y_i[p2][11]}}, y_i[p2]};
    assign y4 = {{12{y_i[p3][11]}}, y_i[p3]};

    wire signed [47:0] cross1 = x1 * y2 - x2 * y1;
    wire signed [47:0] cross2 = x2 * y3 - x3 * y2;
    wire signed [47:0] cross3 = x3 * y4 - x4 * y3;
    wire signed [47:0] cross4 = x4 * y1 - x1 * y4;

    wire signed [49:0] sum_cross = cross1 + cross2 + cross3 + cross4;
    wire signed [49:0] abs_sum = (sum_cross[49]) ? -sum_cross : sum_cross;
    
    // Result needs modulo
    // abs_sum is max roughly 4 * (200*200*2) = 320,000 which fits in 19 bits.
    // But we used wider types for safety.
    wire [31:0] area_val = abs_sum[31:0];
    
    // Next Sum Logic
    wire [31:0] next_sum_add = current_sum + area_val;
    wire [63:0] next_sum_mul = {32'b0, next_sum_add} * MOD;
    // We want modulo, effectively: (current_sum + area) % MOD
    // Since (current_sum + area) < 2*MOD (assuming area < MOD)
    // However, current_sum is accumulated, so it can be up to MOD-1.
    // area_val can be up to ~320k. Sum can be ~1.32M.
    // So we need proper logic: if (next_sum_add >= MOD) next_sum_add - MOD;
    // Let's use a subtractor.
    wire [31:0] next_sum_sub = next_sum_add - MOD;
    wire next_sum_ge_mod = next_sum_add >= MOD;
    
    wire [31:0] next_sum = next_sum_ge_mod ? next_sum_sub : next_sum_add;

    // Helper to increment indices
    reg [2:0] p0_n, p1_n, p2_n, p3_n;
    
    always @(*) begin
        // Default next indices
        p0_n = p0;
        p1_n = p1;
        p2_n = p2;
        p3_n = p3;
        
        // Increment logic: p3++ -> if overflow p2++ -> if overflow p1++ ... etc
        // This is essentially the nested loop unrolling manually
        
        if (p3 < 7) begin
            p3_n = p3 + 1;
        end else begin
            p3_n = p2 + 2; // Reset p3 to p2+1, then increment handled below effectively by carry chain
            // Actually, standard logic:
            // p3 = p2 + 1 initially. If p3 reaches 7, p2 increments.
            // So we need a ripple carry structure.
            
            p3_n = 3'd0;
            if (p2 < 6) begin
                p2_n = p2 + 1;
                p3_n = p2_n + 1; // p3 = p2+1
            end else begin
                p2_n = 3'd0;
                if (p1 < 5) begin
                    p1_n = p1 + 1;
                    p2_n = p1_n + 1;
                    p3_n = p2_n + 1;
                end else begin
                    p1_n = 3'd0;
                    if (p0 < 4) begin
                        p0_n = p0 + 1;
                        p1_n = p0_n + 1;
                        p2_n = p1_n + 1;
                        p3_n = p2_n + 1;
                    end else begin
                        // All done
                        p0_n = 3'd0;
                        p1_n = 3'd1;
                        p2_n = 3'd2;
                        p3_n = 3'd3;
                    end
                end
            end
        end
    end

    // State Machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            total_score <= 0;
            done <= 0;
            combo_idx <= 0;
            current_sum <= 0;
            p0 <= 0; p1 <= 1; p2 <= 2; p3 <= 3;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        state <= CALCULATE;
                        total_score <= 0;
                        current_sum <= 0;
                        combo_idx <= 0;
                        p0 <= 0; p1 <= 1; p2 <= 2; p3 <= 3;
                    end
                end

                CALCULATE: begin
                    // Calculate current quad
                    // Add to current_sum with modulo
                    current_sum <= next_sum;
                    
                    // Move to next quad
                    if (combo_idx < 69) begin
                        combo_idx <= combo_idx + 1;
                        p0 <= p0_n;
                        p1 <= p1_n;
                        p2 <= p2_n;
                        p3 <= p3_n;
                    end else begin
                        // Last quad processed. Update final total_score and move to DONE.
                        total_score <= next_sum; // Update total_score with the final accumulated sum
                        state <= DONE;
                    end
                end

                DONE: begin
                    done <= 1;
                    // Wait for start to go low or reset
                    if (!start) begin
                        state <= IDLE;
                    end
                end
            endcase
        end
    end

endmodule

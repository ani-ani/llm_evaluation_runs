module heap_probability (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [15:0] b_0, b_1, b_2, b_3, b_4, b_5, b_6, b_7,
    input wire [15:0] b_8, b_9, b_10, b_11, b_12, b_13, b_14, b_15,
    input wire [3:0] p_0, p_1, p_2, p_3, p_4, p_5, p_6, p_7,
    input wire [3:0] p_8, p_9, p_10, p_11, p_12, p_13, p_14, p_15,
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;

    // Registers
    reg [1:0] state;
    reg [3:0] idx;
    reg [31:0] prod;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd20;

    // Temporary storage for current edge calculation
    reg [15:0] b_u, b_v;
    reg [31:0] prob_edge;

    // Helper function to get b value by index
    function [15:0] get_b;
        input [3:0] index;
        begin
            case (index)
                4'd0: get_b = b_0;
                4'd1: get_b = b_1;
                4'd2: get_b = b_2;
                4'd3: get_b = b_3;
                4'd4: get_b = b_4;
                4'd5: get_b = b_5;
                4'd6: get_b = b_6;
                4'd7: get_b = b_7;
                4'd8: get_b = b_8;
                4'd9: get_b = b_9;
                4'd10: get_b = b_10;
                4'd11: get_b = b_11;
                4'd12: get_b = b_12;
                4'd13: get_b = b_13;
                4'd14: get_b = b_14;
                4'd15: get_b = b_15;
                default: get_b = 16'd0;
            endcase
        end
    endfunction

    // Helper function to get parent by index
    function [3:0] get_p;
        input [3:0] index;
        begin
            case (index)
                4'd0: get_p = p_0;
                4'd1: get_p = p_1;
                4'd2: get_p = p_2;
                4'd3: get_p = p_3;
                4'd4: get_p = p_4;
                4'd5: get_p = p_5;
                4'd6: get_p = p_6;
                4'd7: get_p = p_7;
                4'd8: get_p = p_8;
                4'd9: get_p = p_9;
                4'd10: get_p = p_10;
                4'd11: get_p = p_11;
                4'd12: get_p = p_12;
                4'd13: get_p = p_13;
                4'd14: get_p = p_14;
                4'd15: get_p = p_15;
                default: get_p = 4'd0;
            endcase
        end
    endfunction

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            idx <= 4'd0;
            prod <= 32'd256; // 1.0 in Q8.8
            cycle_count <= 8'd0;
            b_u <= 16'd0;
            b_v <= 16'd0;
            prob_edge <= 32'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    prod <= 32'd256; // Reset to 1.0
                    idx <= 4'd1; // Start from node 1 (skip root 0)
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE;
                    end
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Get current node and its parent
                    b_v <= get_b(idx);
                    b_u <= get_b(get_p(idx));
                    
                    // Calculate probability for this edge (Q8.8 format)
                    // P(X[u] > X[v]) = min(b_u, b_v) / (2 * max(b_u, b_v))
                    // In Q8.8: (min << 8) / (2 * max)
                    
                    // Use temporary wires for calculation
                    // Since we can't do division in always block, we'll use combinational logic
                    // For now, set a default value
                    prob_edge <= 32'd0;
                    
                    // Process edge and update product
                    if (idx >= n) begin
                        // All edges processed
                        result <= prod;
                        state <= FINISH;
                    end else begin
                        // Calculate probability for current edge
                        // Q8.8 = (min_b * 256) / (2 * max_b)
                        if (b_u >= b_v) begin
                            // b_v is smaller: prob = (b_v << 8) / (2 * b_u)
                            // To avoid division: prob = (b_v * 128) / b_u
                            // But we need exact value - use shift for division by power of 2
                            // Actually, denominator is 2*b_u, so divide by b_u then shift right 1
                            // prob = (b_v * 256) / (2 * b_u) = (b_v * 128) / b_u
                            prob_edge <= (b_v * 16'd128) / b_u;
                        end else begin
                            // b_u is smaller: prob = (b_u << 8) / (2 * b_v)
                            prob_edge <= (b_u * 16'd128) / b_v;
                        end
                        
                        // Multiply product by probability (Q8.8 * Q8.8 = Q16.16, keep Q8.8)
                        prod <= (prod * prob_edge) >> 8;
                        idx <= idx + 4'd1;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    result <= 32'd0;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule
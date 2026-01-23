module min_error (
    input clk,
    input rst_n,
    input start,
    input [15:0] a_0, a_1, a_2, a_3, a_4, a_5, a_6, a_7,
    input [15:0] b_0, b_1, b_2, b_3, b_4, b_5, b_6, b_7,
    input [7:0] k1,
    input [7:0] k2,
    output reg [63:0] result,
    output reg done
);

    // Internal state storage
    reg [15:0] diff [0:7];          // Absolute differences
    reg [7:0] ops_remaining;        // Operations left to perform
    reg [2:0] idx;                  // Loop index
    reg [15:0] max_val;             // Current maximum difference
    reg [2:0] max_idx;              // Index of maximum difference
    reg [63:0] sum;                 // Accumulated sum of squares
    reg [2:0] loop_count;           // Helper counter for loops
    
    // State machine encoding
    reg [2:0] state;
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE_DIFF = 3'd1;
    localparam [2:0] FIND_MAX = 3'd2;
    localparam [2:0] UPDATE = 3'd3;
    localparam [2:0] SUM = 3'd4;
    localparam [2:0] DONE = 3'd5;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 64'd0;
            ops_remaining <= 8'd0;
            idx <= 3'd0;
            max_val <= 16'd0;
            max_idx <= 3'd0;
            sum <= 64'd0;
            loop_count <= 3'd0;
            for (integer i = 0; i < 8; i = i + 1) begin
                diff[i] <= 16'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        ops_remaining <= k1 + k2;
                        idx <= 3'd0;
                        state <= COMPUTE_DIFF;
                    end
                end
                
                COMPUTE_DIFF: begin
                    // Compute absolute differences using conditional logic
                    case (idx)
                        3'd0: begin
                            if ($signed(a_0) > $signed(b_0)) begin
                                diff[0] <= a_0 - b_0;
                            end else begin
                                diff[0] <= b_0 - a_0;
                            end
                        end
                        3'd1: begin
                            if ($signed(a_1) > $signed(b_1)) begin
                                diff[1] <= a_1 - b_1;
                            end else begin
                                diff[1] <= b_1 - a_1;
                            end
                        end
                        3'd2: begin
                            if ($signed(a_2) > $signed(b_2)) begin
                                diff[2] <= a_2 - b_2;
                            end else begin
                                diff[2] <= b_2 - a_2;
                            end
                        end
                        3'd3: begin
                            if ($signed(a_3) > $signed(b_3)) begin
                                diff[3] <= a_3 - b_3;
                            end else begin
                                diff[3] <= b_3 - a_3;
                            end
                        end
                        3'd4: begin
                            if ($signed(a_4) > $signed(b_4)) begin
                                diff[4] <= a_4 - b_4;
                            end else begin
                                diff[4] <= b_4 - a_4;
                            end
                        end
                        3'd5: begin
                            if ($signed(a_5) > $signed(b_5)) begin
                                diff[5] <= a_5 - b_5;
                            end else begin
                                diff[5] <= b_5 - a_5;
                            end
                        end
                        3'd6: begin
                            if ($signed(a_6) > $signed(b_6)) begin
                                diff[6] <= a_6 - b_6;
                            end else begin
                                diff[6] <= b_6 - a_6;
                            end
                        end
                        3'd7: begin
                            if ($signed(a_7) > $signed(b_7)) begin
                                diff[7] <= a_7 - b_7;
                            end else begin
                                diff[7] <= b_7 - a_7;
                            end
                        end
                        default: diff[0] <= 16'd0;
                    endcase
                    
                    idx <= idx + 3'd1;
                    if (idx == 3'd7) begin
                        idx <= 3'd0;
                        max_val <= 16'd0;
                        max_idx <= 3'd0;
                        state <= FIND_MAX;
                    end
                end
                
                FIND_MAX: begin
                    // Scan for maximum difference
                    if (diff[idx] > max_val) begin
                        max_val <= diff[idx];
                        max_idx <= idx;
                    end
                    
                    idx <= idx + 3'd1;
                    if (idx == 3'd7) begin
                        idx <= 3'd0;
                        state <= UPDATE;
                    end
                end
                
                UPDATE: begin
                    if (ops_remaining > 8'd0) begin
                        // Apply operation to maximum difference
                        if (max_val == 16'd0) begin
                            diff[max_idx] <= 16'd1;  // Must use all operations
                        end else begin
                            diff[max_idx] <= max_val - 16'd1;
                        end
                        ops_remaining <= ops_remaining - 8'd1;
                        // Reset for next iteration
                        idx <= 3'd0;
                        max_val <= 16'd0;
                        max_idx <= 3'd0;
                        state <= FIND_MAX;
                    end else begin
                        // All operations complete, compute final sum
                        idx <= 3'd0;
                        sum <= 64'd0;
                        state <= SUM;
                    end
                end
                
                SUM: begin
                    if (idx < 3'd8) begin
                        sum <= sum + (diff[idx] * diff[idx]);
                        idx <= idx + 3'd1;
                    end else begin
                        result <= sum;
                        state <= DONE;
                    end
                end
                
                DONE: begin
                    done <= 1'b1;
                    if (!start) begin
                        state <= IDLE;
                        done <= 1'b0;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule
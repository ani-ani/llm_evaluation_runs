module BracketInversion(
    input clk,
    input rst_n,
    input start,
    input [15:0] seq_i,
    input [3:0] len_i,
    output reg possible,
    output reg done
);
    // State definitions
    localparam [2:0] IDLE     = 3'd0;
    localparam [2:0] CHECK    = 3'd1;
    localparam [2:0] VERIFY   = 3'd2;
    localparam [2:0] NEXT_SEG = 3'd3;
    localparam [2:0] FINISH   = 3'd4;
    
    // Internal registers
    reg [2:0] state;
    reg [3:0] len_reg;          // Registered length
    reg [3:0] l;                // Start index of segment
    reg [3:0] r;                // End index of segment
    reg [3:0] idx;              // Current index for balance check
    reg [4:0] balance;          // Current balance (can go negative, up to -16 to +16)
    reg valid_seg;              // Valid flag for current segment
    reg found_any;              // Found at least one valid configuration
    reg [7:0] cycle_count;      // Prevent infinite loops
    localparam [7:0] MAX_CYCLES = 8'd200;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            possible <= 1'b0;
            done <= 1'b0;
            len_reg <= 4'd0;
            l <= 4'd0;
            r <= 4'd0;
            idx <= 4'd0;
            balance <= 5'd0;
            valid_seg <= 1'b0;
            found_any <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    possible <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        len_reg <= len_i;
                        l <= 4'd0;
                        r <= 4'd0;
                        found_any <= 1'b0;
                        state <= CHECK;
                    end
                end

                CHECK: begin
                    // Check if current segment (l, r) is valid
                    // Initialize for balance check
                    idx <= 4'd0;
                    balance <= 5'd0;
                    valid_seg <= 1'b1;
                    state <= VERIFY;
                end

                VERIFY: begin
                    // Check if we've reached end of sequence
                    if (idx == len_reg) begin
                        // End of sequence reached
                        if (balance == 5'd0 && valid_seg) begin
                            found_any <= 1'b1;
                        end
                        state <= NEXT_SEG;
                    end else begin
                        // Check current bracket
                        if (idx >= l && idx <= r) begin
                            // Inside inverted segment: flip bit
                            if (~seq_i[idx]) begin
                                balance <= balance + 5'd1;  // Was 0, now 1
                            end else begin
                                balance <= balance - 5'd1;  // Was 1, now 0
                            end
                        end else begin
                            // Outside inverted segment: normal
                            if (seq_i[idx]) begin
                                balance <= balance + 5'd1;
                            end else begin
                                balance <= balance - 5'd1;
                            end
                        end
                        
                        // Update validity based on balance
                        if (balance < 5'd16) begin
                            // Wait, balance < 0 means invalid
                            // Using 5'd16 as -16 (offset representation)
                            // Actually, let's track signed properly
                            if ($signed(balance) < 0) begin
                                valid_seg <= 1'b0;
                            end
                        end
                        
                        idx <= idx + 4'd1;
                        cycle_count <= cycle_count + 8'd1;
                        
                        if (cycle_count >= MAX_CYCLES) begin
                            state <= FINISH;
                        end
                    end
                end

                NEXT_SEG: begin
                    // Move to next segment (l, r) pair
                    if (r < len_reg - 4'd1) begin
                        r <= r + 4'd1;
                        state <= CHECK;
                    end else begin
                        // r at end, move l
                        if (l < len_reg - 4'd1) begin
                            l <= l + 4'd1;
                            r <= l + 4'd1;  // Reset r to l+1 for new segment
                            state <= CHECK;
                        end else begin
                            // All segments checked
                            state <= FINISH;
                        end
                    end
                    
                    cycle_count <= cycle_count + 8'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    possible <= found_any;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule
module CountInRange (
    input clk,
    input rst_n,
    input start,
    input [33:0] min_val,
    input [33:0] max_val,
    output reg [23:0] count,
    output reg done
);
    // State definitions
    localparam [2:0] IDLE     = 3'd0;
    localparam [2:0] CHECK    = 3'd1;
    localparam [2:0] INCR     = 3'd2;
    localparam [2:0] REV_OP   = 3'd3;
    localparam [2:0] NEXT_ROW = 3'd4;
    localparam [2:0] FINISH   = 3'd5;

    // Registers
    reg [2:0] state, next_state;
    reg [5:0] row;        // 1 to 64 (0-63 internal)
    reg [33:0] current_val;
    reg [33:0] rev_temp;
    reg [5:0] digit_idx;  // For digit extraction (0-33)
    reg [33:0] rev_val;   // Accumulated reversed value
    reg [33:0] next_val;
    reg counting_active;

    // Internal signals
    wire [33:0] rev_result;
    wire [3:0] digit;
    wire [33:0] next_val_wire;
    
    // Extract current digit (decimal)
    assign digit = current_val[digit_idx*4 +: 4];
    
    // Compute next_val = current_val + rev(current_val)
    assign next_val_wire = current_val + rev_val;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            count <= 24'd0;
            done <= 1'b0;
            row <= 6'd0;
            current_val <= 34'd0;
            rev_val <= 34'd0;
            next_val <= 34'd0;
            digit_idx <= 6'd0;
            counting_active <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= INCR;
                        count <= 24'd0;
                        row <= 6'd0; // Will become 1 on first increment
                        counting_active <= 1'b0;
                    end
                end

                INCR: begin
                    // Increment row (1 to 64)
                    if (row < 6'd64) begin
                        row <= row + 6'd1;
                        current_val <= {28'd0, row + 6'd1}; // row is 0-63, so +1 = 1-64
                        state <= CHECK;
                    end else begin
                        state <= FINISH;
                    end
                end

                CHECK: begin
                    // Check if current_val is in range
                    if (current_val >= min_val && current_val <= max_val) begin
                        count <= count + 24'd1;
                    end
                    
                    // If current_val > max_val, stop this row
                    if (current_val > max_val) begin
                        state <= INCR;
                    end else begin
                        // Prepare for rev calculation
                        rev_val <= 34'd0;
                        digit_idx <= 6'd0; // Start from least significant digit
                        state <= REV_OP;
                    end
                end

                REV_OP: begin
                    // Compute reverse of current_val (decimal digits)
                    // We process 34 digits (4 bits each) from right to left
                    if (digit_idx < 6'd34) begin
                        // Accumulate: rev_val = rev_val * 10 + digit
                        rev_val <= rev_val * 10 + digit;
                        digit_idx <= digit_idx + 6'd1;
                        state <= REV_OP;
                    end else begin
                        // Done reversing
                        state <= NEXT_ROW;
                    end
                end

                NEXT_ROW: begin
                    // Compute next value
                    current_val <= next_val_wire;
                    // Check if we should stop the row (next_val > max_val)
                    // We will check in CHECK state
                    if (next_val_wire > max_val) begin
                        state <= INCR; // Move to next row
                    end else begin
                        state <= CHECK; // Check this new value
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule
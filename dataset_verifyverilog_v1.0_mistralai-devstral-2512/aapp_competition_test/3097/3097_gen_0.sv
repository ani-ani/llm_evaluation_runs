module CountInRange(
    input clk,
    input rst_n,
    input start,
    input [33:0] min_val,
    input [33:0] max_val,
    output reg [23:0] count,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] INIT    = 3'd1;
    localparam [2:0] PROCESS = 3'd2;
    localparam [2:0] REV     = 3'd3;
    localparam [2:0] UPDATE  = 3'd4;
    localparam [2:0] FINISH  = 3'd5;

    reg [2:0] state, next_state;
    reg [5:0] row;           // Row counter (1 to 64)
    reg [33:0] current_val;  // Current value in sequence
    reg [33:0] next_val;     // Next value in sequence
    reg [33:0] rev_val;      // Reversed value
    reg [3:0] rev_digit;     // Current digit being processed
    reg [33:0] rev_temp;     // Temporary storage for reversal
    reg [5:0] digit_pos;     // Current digit position (0 to 9)
    reg [5:0] cycle_count;  // Prevent infinite loops
    localparam [5:0] MAX_CYCLES = 6'd1024;

    // Reversal logic (combinational)
    always @(*) begin
        rev_temp = 34'd0;
        rev_val = 34'd0;
        if (current_val == 34'd0) begin
            rev_val = 34'd0;
        end else begin
            // Extract digits and build reversed number
            rev_temp = current_val;
            rev_val = 34'd0;
            for (digit_pos = 0; digit_pos < 10; digit_pos = digit_pos + 1) begin
                rev_digit = rev_temp % 10;
                rev_val = rev_val * 10 + rev_digit;
                rev_temp = rev_temp / 10;
            end
        end
    end

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            count <= 24'd0;
            done <= 1'b0;
            row <= 6'd0;
            current_val <= 34'd0;
            next_val <= 34'd0;
            rev_val <= 34'd0;
            digit_pos <= 5'd0;
            cycle_count <= 6'd0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 6'd0;
                    if (start) begin
                        next_state <= INIT;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                INIT: begin
                    count <= 24'd0;
                    row <= 6'd1;
                    current_val <= 34'd1;
                    next_state <= PROCESS;
                end

                PROCESS: begin
                    cycle_count <= cycle_count + 6'd1;
                    if (current_val >= min_val && current_val <= max_val) begin
                        count <= count + 24'd1;
                    end
                    if (current_val > max_val || cycle_count >= MAX_CYCLES) begin
                        if (row == 6'd64) begin
                            next_state <= FINISH;
                        end else begin
                            row <= row + 6'd1;
                            current_val <= row;
                            next_state <= PROCESS;
                        end
                    end else begin
                        next_state <= REV;
                    end
                end

                REV: begin
                    next_val <= current_val + rev_val;
                    next_state <= UPDATE;
                end

                UPDATE: begin
                    current_val <= next_val;
                    next_state <= PROCESS;
                end

                FINISH: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule
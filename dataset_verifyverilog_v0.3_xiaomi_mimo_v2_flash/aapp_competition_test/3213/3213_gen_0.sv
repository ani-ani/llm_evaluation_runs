module spell_optimizer #(
    parameter M = 8,          // Number of steps (max 8)
    parameter S = 4           // Strength (modulo 2^S = 16)
)(
    input clk,
    input rst_n,
    input start,
    input [7:0] steps [0:M-1],    // Input steps as ASCII array
    output reg [7:0] result [0:M-1], // Output string with 'o' replacements
    output reg done
);

// State definitions
localparam STATE_IDLE = 3'b000;
localparam STATE_EVAL_INIT = 3'b001;
localparam STATE_EVAL_LOOP = 3'b010;
localparam STATE_EVAL_DONE = 3'b011;
localparam STATE_NEXT_MASK = 3'b100;
localparam STATE_DONE = 3'b101;
localparam STATE_CONVERT = 3'b110;

// Registers
reg [2:0] state;
reg [M-1:0] mask_reg;           // Current mask being evaluated
reg [2:0] idx_reg;              // Current step index
reg [S-1:0] val_reg;            // Current computed value
reg [S-1:0] best_val_reg;       // Best value found
reg [M-1:0] best_mask_reg;      // Best mask found
reg [7:0] steps_reg [0:M-1];    // Store input steps
reg [2:0] convert_idx;          // Index for conversion loop

// Combinational logic for evaluation
wire [S-1:0] next_val_add;
wire [S-1:0] next_val_mul;

// Next value after +1 (mod 2^S)
assign next_val_add = val_reg + 1'b1;

// Next value after *2 (mod 2^S) - left shift and truncate
assign next_val_mul = val_reg << 1;

// State machine and sequential logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Reset all registers
        state <= STATE_IDLE;
        mask_reg <= 0;
        idx_reg <= 0;
        val_reg <= 0;
        best_val_reg <= 0;
        best_mask_reg <= 0;
        convert_idx <= 0;
        done <= 0;
        // Reset result array
        for (integer i = 0; i < M; i = i + 1) begin
            result[i] <= 8'h00;
        end
        // Reset steps_reg
        for (integer i = 0; i < M; i = i + 1) begin
            steps_reg[i] <= 8'h00;
        end
    end else begin
        case (state)
            STATE_IDLE: begin
                done <= 0;
                if (start) begin
                    // Capture input steps and initialize
                    for (integer i = 0; i < M; i = i + 1) begin
                        steps_reg[i] <= steps[i];
                    end
                    mask_reg <= 0;
                    best_val_reg <= 0;
                    best_mask_reg <= 0;
                    state <= STATE_EVAL_INIT;
                end
            end

            STATE_EVAL_INIT: begin
                // Initialize evaluation of current mask
                val_reg <= 1'b1;   // Start with power = 1
                idx_reg <= 0;
                state <= STATE_EVAL_LOOP;
            end

            STATE_EVAL_LOOP: begin
                if (idx_reg < M) begin
                    // Check if current step is kept (mask bit = 1)
                    if (mask_reg[idx_reg]) begin
                        // Apply operation
                        case (steps_reg[idx_reg])
                            8'h2B: begin // '+' character
                                val_reg <= next_val_add;
                            end
                            8'h78: begin // 'x' character
                                val_reg <= next_val_mul;
                            end
                            default: begin
                                // No operation for invalid chars
                                val_reg <= val_reg;
                            end
                        endcase
                    end
                    idx_reg <= idx_reg + 1'b1;
                end else begin
                    // Finished evaluating this mask
                    state <= STATE_EVAL_DONE;
                end
            end

            STATE_EVAL_DONE: begin
                // Compare with best value found so far
                if (val_reg > best_val_reg) begin
                    best_val_reg <= val_reg;
                    best_mask_reg <= mask_reg;
                end
                state <= STATE_NEXT_MASK;
            end

            STATE_NEXT_MASK: begin
                // Move to next mask
                mask_reg <= mask_reg + 1'b1;
                // Check for wrap-around (all masks evaluated)
                if ((mask_reg + 1'b1) == 0) begin
                    state <= STATE_CONVERT;
                    convert_idx <= 0;
                end else begin
                    state <= STATE_EVAL_INIT;
                end
            end

            STATE_CONVERT: begin
                // Convert best_mask_reg to output string
                if (convert_idx < M) begin
                    if (best_mask_reg[convert_idx]) begin
                        // Keep original step
                        result[convert_idx] <= steps_reg[convert_idx];
                    end else begin
                        // Replace with 'o'
                        result[convert_idx] <= 8'h6F; // ASCII 'o'
                    end
                    convert_idx <= convert_idx + 1'b1;
                end else begin
                    // Conversion complete
                    done <= 1;
                    state <= STATE_DONE;
                end
            end

            STATE_DONE: begin
                // Wait for reset or new start
                // done remains high until reset
                if (!start) begin
                    done <= 1;
                end else begin
                    // If start is asserted again, reinitialize
                    state <= STATE_IDLE;
                    done <= 0;
                end
            end

            default: begin
                state <= STATE_IDLE;
            end
        endcase
    end
end

endmodule
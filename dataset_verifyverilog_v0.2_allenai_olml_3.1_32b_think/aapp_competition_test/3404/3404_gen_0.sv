module martian_decrypter (input wire clk, input wire rst_n, input wire start, input wire [3:0] char_in, // Input character value (0-26)
input wire char_valid,     // Input character valid
output reg [3:0] char_out, // Decrypted character value (0-26)
output reg char_out_valid, // Output valid
output reg done            // All messages processed
);

    // Parameters for scaling
    parameter X_SIZE = 4; // Scaled down from 250,000 to 4 (2x2 grid)
    parameter MSG_LEN = 8; // Scaled down from 10^6 to 8
    parameter MOD_VAL = 256; // 2^8 for scaling (was 2^20)

    // State definitions
    localparam IDLE = 3'b000;
    localparam GEN_GRID = 3'b001;
    localparam CALC_SUMS = 3'b010;
    localparam WAIT_INPUT = 3'b011;
    localparam DECRYPT = 3'b100;

    reg [2:0] state;
    reg [2:0] next_state;

    // Grid generation registers
    reg [7:0] f_current; // Current value in sequence f^i(0)
    reg [7:0] f_next;    // Next value f(f_current)
    reg [2:0] col_idx;   // Column index (0 to X_SIZE-1)
    reg [2:0] row_idx;   // Row index (0 to X_SIZE-1)
    reg [7:0] col_sums [0:X_SIZE-1]; // Column sums 

    // Input buffer
    reg [3:0] msg_buffer [0:MSG_LEN-1];
    reg [3:0] msg_idx;
    reg [3:0] input_idx;

    // Pad storage (Base 27 digits)
    reg [4:0] pad_digits [0:MSG_LEN-1];
    reg [2:0] pad_idx;

    // Sequential state transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: if (start) next_state = GEN_GRID;

            GEN_GRID: begin
                // Wait for grid generation (X_SIZE * X_SIZE cycles)
                if (row_idx == X_SIZE - 1 && col_idx == X_SIZE - 1)
                    next_state = CALC_SUMS;
                else
                    next_state = GEN_GRID;
            end

            CALC_SUMS: next_state = WAIT_INPUT;

            WAIT_INPUT: begin
                if (char_valid) next_state = DECRYPT;
            end

            DECRYPT: begin
                if (msg_idx >= MSG_LEN - 1 || !char_valid) next_state = WAIT_INPUT;
            end

            default: next_state = IDLE;
        endcase
    end

    // Datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            f_current <= 8'd0;
            f_next <= 8'd1; // f(0) = (33*0+1) mod 256 = 1
            col_idx <= 3'd0;
            row_idx <= 3'd0;
            msg_idx <= 4'd0;
            input_idx <= 4'd0;
            pad_idx <= 3'd0;
            char_out_valid <= 1'b0;
            done <= 1'b0;
            // Reset sums
            col_sums[0] <= 8'd0;
            col_sums[1] <= 8'd0;
            col_sums[2] <= 8'd0;
            col_sums[3] <= 8'd0;
        end else begin
            char_out_valid <= 1'b0;

            case (state)
                IDLE: begin
                    if (start) begin
                        f_current <= 8'd0;
                        f_next <= 8'd1;
                        col_idx <= 3'd0;
                        row_idx <= 3'd0;
                        msg_idx <= 4'd0;
                        input_idx <= 4'd0;
                        pad_idx <= 3'd0;
                    end
                end

                GEN_GRID: begin
                    // Fill grid cell with f_next
                    // Update column sum
                    col_sums[col_idx] <= col_sums[col_idx] + f_next;

                    // Calculate next f value: f(x) = (33x + 1) % 256
                    // Optimized: 33x = 32x + x. In verilog this is just multiplication.
                    f_current <= f_next;
                    f_next <= (33 * f_next + 1) % MOD_VAL;

                    // Increment indices
                    if (col_idx == X_SIZE - 1) begin
                        col_idx <= 3'd0;
                        if (row_idx == X_SIZE - 1) begin
                            // Done, stay here until next state transition
                        end else begin
                            row_idx <= row_idx + 1'b1;
                        end
                    end else begin
                        col_idx <= col_idx + 1'b1;
                    end
                end

                CALC_SUMS: begin
                    // Convert column sums to Base 27 digits (Step 4 & 5)
                    // Since inputs are small, we simulate the "concatenate then convert" logic
                    // by just taking the sum modulo 27.
                    // For a real large problem, we would need to implement BigInt base conversion.
                    // Here: Pad[i] = Sum[i] % 27
                    if (pad_idx < X_SIZE) begin
                        pad_digits[pad_idx] <= col_sums[pad_idx] % 5'd27;
                        pad_idx <= pad_idx + 1'b1;
                    end
                end

                WAIT_INPUT: begin
                    if (char_valid) begin
                        msg_buffer[input_idx] <= char_in;
                        input_idx <= input_idx + 1'b1;
                    end
                end

                DECRYPT: begin
                    // Step 6: Shift cipher
                    // Decrypted = (Encrypted + Pad) % 27
                    // Pad repeats if message is longer than grid (X_SIZE*X_SIZE)
                    // But here msg_len is limited to MSG_LEN.
                    if (char_valid) begin
                        msg_buffer[input_idx] <= char_in; // Buffer next char
                        input_idx <= input_idx + 1'b1;

                        // Output previous char decryption
                        // Use modulo arithmetic
                        char_out <= (msg_buffer[msg_idx] + pad_digits[msg_idx % X_SIZE]) % 5'd27;
                        char_out_valid <= 1'b1;

                        msg_idx <= msg_idx + 1'b1;

                        if (msg_idx == MSG_LEN - 1) begin
                            done <= 1'b1;
                        end
                    end
                end
            endcase
        end
    end

endmodule
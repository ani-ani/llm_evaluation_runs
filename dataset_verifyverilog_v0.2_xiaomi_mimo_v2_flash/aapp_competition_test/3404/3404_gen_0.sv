module martian_decrypter (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] char_in,
    input wire char_valid,
    output reg [3:0] char_out,
    output reg char_out_valid,
    output reg done
);

    // Parameters for scaling
    parameter X_SIZE = 4;
    parameter MSG_LEN = 8;
    parameter MOD_VAL = 256;

    // State definitions
    localparam IDLE = 3'b000;
    localparam GEN_GRID = 3'b001;
    localparam CALC_SUMS = 3'b010;
    localparam WAIT_INPUT = 3'b011;
    localparam DECRYPT = 3'b100;

    reg [2:0] state;
    reg [2:0] next_state;

    // Grid generation registers
    reg [7:0] f_next;
    reg [2:0] col_idx;
    reg [2:0] row_idx;
    reg [7:0] col_sums [0:X_SIZE-1];
    
    // Input buffer and control
    reg [3:0] msg_buffer [0:MSG_LEN-1];
    reg [3:0] msg_idx;
    reg [3:0] input_idx;
    
    // Pad storage
    reg [4:0] pad_digits [0:X_SIZE-1];
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
                if (row_idx == X_SIZE - 1 && col_idx == X_SIZE - 1)
                    next_state = CALC_SUMS;
                else
                    next_state = GEN_GRID;
            end
            
            CALC_SUMS: begin
                if (pad_idx == X_SIZE)
                    next_state = WAIT_INPUT;
                else
                    next_state = CALC_SUMS;
            end
            
            WAIT_INPUT: begin
                if (char_valid) next_state = DECRYPT;
            end
            
            DECRYPT: begin
                // Transition back to WAIT_INPUT after processing one char
                // to handle streaming input properly
                if (char_valid) begin
                     if (msg_idx == MSG_LEN - 1)
                        next_state = IDLE; // Done with full message
                     else
                        next_state = WAIT_INPUT;
                end
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            f_next <= 8'd1;
            col_idx <= 3'd0;
            row_idx <= 3'd0;
            msg_idx <= 4'd0;
            input_idx <= 4'd0;
            pad_idx <= 3'd0;
            char_out_valid <= 1'b0;
            done <= 1'b0;
            for (int i = 0; i < X_SIZE; i++) col_sums[i] <= 8'd0;
        end else begin
            char_out_valid <= 1'b0;
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    if (start) begin
                        f_next <= 8'd1;
                        col_idx <= 3'd0;
                        row_idx <= 3'd0;
                        msg_idx <= 4'd0;
                        input_idx <= 4'd0;
                        pad_idx <= 3'd0;
                        // Sums reset in next block or here
                        for (int i = 0; i < X_SIZE; i++) col_sums[i] <= 8'd0;
                    end
                end

                GEN_GRID: begin
                    // Fill grid cell with f_next
                    col_sums[col_idx] <= col_sums[col_idx] + f_next;
                    
                    // Calculate next f value
                    f_next <= (33 * f_next + 1) % MOD_VAL;
                    
                    // Increment indices
                    if (col_idx == X_SIZE - 1) begin
                        col_idx <= 3'd0;
                        if (row_idx < X_SIZE - 1)
                            row_idx <= row_idx + 1'b1;
                    end else begin
                        col_idx <= col_idx + 1'b1;
                    end
                end

                CALC_SUMS: begin
                    if (pad_idx < X_SIZE) begin
                        pad_digits[pad_idx] <= col_sums[pad_idx] % 5'd27;
                        pad_idx <= pad_idx + 1'b1;
                    end
                end

                WAIT_INPUT: begin
                    // Buffer incoming char
                    if (char_valid) begin
                        msg_buffer[input_idx] <= char_in;
                        input_idx <= input_idx + 1'b1;
                    end
                end

                DECRYPT: begin
                    if (char_valid) begin
                        // Output decryption for the previously stored char at msg_idx
                        char_out <= (msg_buffer[msg_idx] + pad_digits[msg_idx % X_SIZE]) % 5'd27;
                        char_out_valid <= 1'b1;
                        
                        // Buffer the NEW incoming char (already done in WAIT_INPUT transition logic typically,
                        // but if we stay in DECRYPT for multi-char burst, we need to handle it here)
                        // Based on state transition logic, we go to WAIT_INPUT after one char.
                        // However, we must capture the char that triggers this state.
                        // To be safe, buffer input in DECRYPT too if input_idx hasn't caught up.
                        // Actually, the WAIT_INPUT state handles the capture. 
                        // Let's assume the input triggers the transition from WAIT_INPUT to DECRYPT.
                        // The char_in valid at that edge must be stored.
                        // If we are strictly one char per cycle with gap, the logic holds.
                        // If streaming (gap=0), we need to buffer continuously.
                        
                        // Robust buffering:
                        msg_buffer[input_idx] <= char_in;
                        input_idx <= input_idx + 1'b1;
                        
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
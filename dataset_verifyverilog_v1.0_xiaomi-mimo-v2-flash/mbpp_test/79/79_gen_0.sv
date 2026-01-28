module FirstWordOddLength(
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    output reg result,
    output reg done
);
    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] IN_WORD = 2'd1;
    localparam [1:0] AFTER_WORD = 2'd2;
    localparam [1:0] DONE_STATE = 2'd3;

    // Internal registers
    reg [1:0] state;
    reg [4:0] length_counter;  // Max 16, 5 bits sufficient
    reg word_active;
    reg [7:0] saved_char;
    reg [6:0] cycle_count;     // Safety counter (max 100 cycles)
    localparam [6:0] MAX_CYCLES = 7'd100;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            length_counter <= 5'd0;
            word_active <= 1'b0;
            saved_char <= 8'd0;
            cycle_count <= 7'd0;
        end else begin
            // Default assignments
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    cycle_count <= 7'd0;
                    length_counter <= 5'd0;
                    word_active <= 1'b0;
                    saved_char <= 8'd0;
                    
                    if (start) begin
                        state <= IN_WORD;
                    end
                end

                IN_WORD: begin
                    cycle_count <= cycle_count + 7'd1;
                    
                    // Check for null terminator or space (end of word)
                    if (char_in == 8'h00 || char_in == 8'h20) begin
                        // End of first word
                        if (length_counter > 5'd0) begin
                            // Word was active, determine result
                            result <= length_counter[0];  // Check LSB for odd
                            state <= (char_in == 8'h00) ? DONE_STATE : AFTER_WORD;
                        end else begin
                            // No word found yet, keep looking
                            if (char_in == 8'h00) begin
                                result <= 1'b0;
                                state <= DONE_STATE;
                            end
                        end
                    end else begin
                        // Character is part of word
                        if (length_counter < 5'd16) begin
                            length_counter <= length_counter + 5'd1;
                        end
                        word_active <= 1'b1;
                    end
                    
                    // Safety timeout
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= DONE_STATE;
                    end
                end

                AFTER_WORD: begin
                    cycle_count <= cycle_count + 7'd1;
                    
                    // Ignore all characters until null
                    if (char_in == 8'h00) begin
                        state <= DONE_STATE;
                    end
                    
                    // Safety timeout
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule
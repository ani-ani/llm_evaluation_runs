module string_concat (
    input clk,
    input rst_n,
    input start,
    input [7:0] str0 [0:7],
    input [7:0] str1 [0:7],
    input [7:0] str2 [0:7],
    input [7:0] str3 [0:7],
    input [1:0] count,
    output reg [7:0] result [0:31],
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESSING = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    // Internal registers
    reg [1:0] state, next_state;
    reg [4:0] byte_index;       // 0-31 (32 bytes)
    reg [1:0] string_index;     // 0-3 (4 strings)
    reg [2:0] char_index;       // 0-7 (8 characters per string)
    reg [4:0] cycle_counter;    // Prevent infinite loops
    localparam [4:0] MAX_CYCLES = 5'd36;

    // State transition and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            byte_index <= 5'd0;
            string_index <= 2'd0;
            char_index <= 3'd0;
            cycle_counter <= 5'd0;
            // Initialize result array to null bytes
            result[0] <= 8'd0;
            result[1] <= 8'd0;
            result[2] <= 8'd0;
            result[3] <= 8'd0;
            result[4] <= 8'd0;
            result[5] <= 8'd0;
            result[6] <= 8'd0;
            result[7] <= 8'd0;
            result[8] <= 8'd0;
            result[9] <= 8'd0;
            result[10] <= 8'd0;
            result[11] <= 8'd0;
            result[12] <= 8'd0;
            result[13] <= 8'd0;
            result[14] <= 8'd0;
            result[15] <= 8'd0;
            result[16] <= 8'd0;
            result[17] <= 8'd0;
            result[18] <= 8'd0;
            result[19] <= 8'd0;
            result[20] <= 8'd0;
            result[21] <= 8'd0;
            result[22] <= 8'd0;
            result[23] <= 8'd0;
            result[24] <= 8'd0;
            result[25] <= 8'd0;
            result[26] <= 8'd0;
            result[27] <= 8'd0;
            result[28] <= 8'd0;
            result[29] <= 8'd0;
            result[30] <= 8'd0;
            result[31] <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    byte_index <= 5'd0;
                    string_index <= 2'd0;
                    char_index <= 3'd0;
                    cycle_counter <= 5'd0;
                    if (start) begin
                        state <= PROCESSING;
                        // Initialize result array with nulls
                        result[0] <= 8'd0;
                        result[1] <= 8'd0;
                        result[2] <= 8'd0;
                        result[3] <= 8'd0;
                        result[4] <= 8'd0;
                        result[5] <= 8'd0;
                        result[6] <= 8'd0;
                        result[7] <= 8'd0;
                        result[8] <= 8'd0;
                        result[9] <= 8'd0;
                        result[10] <= 8'd0;
                        result[11] <= 8'd0;
                        result[12] <= 8'd0;
                        result[13] <= 8'd0;
                        result[14] <= 8'd0;
                        result[15] <= 8'd0;
                        result[16] <= 8'd0;
                        result[17] <= 8'd0;
                        result[18] <= 8'd0;
                        result[19] <= 8'd0;
                        result[20] <= 8'd0;
                        result[21] <= 8'd0;
                        result[22] <= 8'd0;
                        result[23] <= 8'd0;
                        result[24] <= 8'd0;
                        result[25] <= 8'd0;
                        result[26] <= 8'd0;
                        result[27] <= 8'd0;
                        result[28] <= 8'd0;
                        result[29] <= 8'd0;
                        result[30] <= 8'd0;
                        result[31] <= 8'd0;
                    end
                end

                PROCESSING: begin
                    cycle_counter <= cycle_counter + 5'd1;
                    
                    // Copy current character based on string_index and char_index
                    case (string_index)
                        2'd0: begin
                            result[byte_index] <= str0[char_index];
                        end
                        2'd1: begin
                            result[byte_index] <= str1[char_index];
                        end
                        2'd2: begin
                            result[byte_index] <= str2[char_index];
                        end
                        2'd3: begin
                            result[byte_index] <= str3[char_index];
                        end
                        default: begin
                            result[byte_index] <= 8'd0;
                        end
                    endcase

                    // Increment indices
                    if (char_index < 3'd7) begin
                        char_index <= char_index + 3'd1;
                        byte_index <= byte_index + 5'd1;
                    end else begin
                        // End of current string
                        char_index <= 3'd0;
                        byte_index <= byte_index + 5'd1;
                        
                        // Check if we need to move to next string or finish
                        if (string_index < count) begin
                            string_index <= string_index + 2'd1;
                        end else begin
                            // Done with all strings or count reached
                            state <= DONE_STATE;
                        end
                    end

                    // Safety timeout
                    if (cycle_counter >= MAX_CYCLES) begin
                        state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule
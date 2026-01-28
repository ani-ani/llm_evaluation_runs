module vowel_counter (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] str_data [0:15],
    input wire [3:0] str_len,
    output reg [3:0] result,
    output reg done
);

    // FSM States
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] CHECK_CHAR = 3'd1;
    localparam [2:0] INCREMENT  = 3'd2;
    localparam [3:0] DONE_STATE = 3'd3;

    // Internal Registers
    reg [2:0] state, next_state;
    reg [3:0] index;          // Current character index (0-15)
    reg [3:0] count_reg;      // Vowel counter
    reg [7:0] char;           // Current character buffer
    reg is_y_end;             // Flag for y at end of string

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = CHECK_CHAR;
                else
                    next_state = IDLE;
            end
            CHECK_CHAR: begin
                if (index < str_len)
                    next_state = INCREMENT;
                else
                    next_state = DONE_STATE;
            end
            INCREMENT: begin
                next_state = CHECK_CHAR;
            end
            DONE_STATE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 4'd0;
            done <= 1'b0;
            index <= 4'd0;
            count_reg <= 4'd0;
            char <= 8'd0;
            is_y_end <= 1'b0;
        end else begin
            state <= next_state;

            case (next_state)
                IDLE: begin
                    done <= 1'b0;
                    index <= 4'd0;
                    count_reg <= 4'd0;
                    is_y_end <= 1'b0;
                end
                CHECK_CHAR: begin
                    if (index < str_len) begin
                        char <= str_data[index];
                        // Check if current char is 'y' at the end of the string
                        // str_len-1 is the last valid character index
                        if ((index == str_len - 4'd1) && 
                            (str_data[index] == 8'h79 || str_data[index] == 8'h59)) begin
                            is_y_end <= 1'b1;
                        end else begin
                            is_y_end <= 1'b0;
                        end
                    end
                end
                INCREMENT: begin
                    // Vowel check logic
                    // Standard vowels: a, e, i, o, u (case insensitive)
                    // 0x61-0x65 (a-e), 0x69 (i), 0x6F (o), 0x75 (u)
                    // 0x41-0x45 (A-E), 0x49 (I), 0x4F (O), 0x55 (U)
                    if ((char >= 8'h61 && char <= 8'h65) || 
                        (char == 8'h69) || 
                        (char == 8'h6F) || 
                        (char == 8'h75) ||
                        (char >= 8'h41 && char <= 8'h45) || 
                        (char == 8'h49) || 
                        (char == 8'h4F) || 
                        (char == 8'h55)) begin
                        count_reg <= count_reg + 4'd1;
                    end
                    // Special 'y' check (count only if at end)
                    else if (is_y_end && (char == 8'h79 || char == 8'h59)) begin
                        count_reg <= count_reg + 4'd1;
                    end
                    // Increment index
                    index <= index + 4'd1;
                end
                DONE_STATE: begin
                    result <= count_reg;
                    done <= 1'b1;
                end
                default: begin
                    state <= IDLE;
                    result <= 4'd0;
                    done <= 1'b0;
                    index <= 4'd0;
                    count_reg <= 4'd0;
                    char <= 8'd0;
                    is_y_end <= 1'b0;
                end
            endcase
        end
    end

endmodule
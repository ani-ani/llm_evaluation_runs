module odd_count(
    input clk,
    input rst_n,
    input start,
    input [7:0] char_0, char_1, char_2, char_3, char_4, char_5, char_6, char_7,
    output reg [7:0] out_0, out_1, out_2, out_3, out_4, out_5, out_6, out_7,
    out_8, out_9, out_10, out_11, out_12, out_13, out_14, out_15,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE     = 2'd0;
    localparam [1:0] COUNT    = 2'd1;
    localparam [1:0] FORMAT   = 2'd2;
    localparam [1:0] FINISH   = 2'd3;

    reg [1:0] state, next_state;
    reg [3:0] counter;          // Counts 0-7 for processing characters
    reg [3:0] odd_count;        // Stores count of odd digits (0-8)
    reg [7:0] odd_count_ascii;  // ASCII version of count
    reg done_reg;

    // Combinational logic for odd detection
    wire [7:0] char_array [0:7];
    assign char_array[0] = char_0;
    assign char_array[1] = char_1;
    assign char_array[2] = char_2;
    assign char_array[3] = char_3;
    assign char_array[4] = char_4;
    assign char_array[5] = char_5;
    assign char_array[6] = char_6;
    assign char_array[7] = char_7;

    // Odd digit detection: check if bit 0 is 1 (assuming ASCII '0'-'9' where even chars have even values)
    wire [0:7] is_odd;
    assign is_odd[0] = char_array[0][0];
    assign is_odd[1] = char_array[1][0];
    assign is_odd[2] = char_array[2][0];
    assign is_odd[3] = char_array[3][0];
    assign is_odd[4] = char_array[4][0];
    assign is_odd[5] = char_array[5][0];
    assign is_odd[6] = char_array[6][0];
    assign is_odd[7] = char_array[7][0];

    // ASCII to count conversion for output
    wire [7:0] count_to_ascii;
    assign count_to_ascii = 8'h30 + odd_count;

    // Fixed string template: " odd elements  " (15 chars with leading space, trailing spaces to fill 16)
    // Position 0: count digit (handled in state)
    // Positions 1-15: fixed string
    wire [7:0] fixed_string [0:14];
    assign fixed_string[0]  = 8'h20;  // ' ' (space)
    assign fixed_string[1]  = 8'h6F;  // 'o'
    assign fixed_string[2]  = 8'h64;  // 'd'
    assign fixed_string[3]  = 8'h64;  // 'd'
    assign fixed_string[4]  = 8'h20;  // ' ' (space)
    assign fixed_string[5]  = 8'h65;  // 'e'
    assign fixed_string[6]  = 8'h6C;  // 'l'
    assign fixed_string[7]  = 8'h65;  // 'e'
    assign fixed_string[8]  = 8'h6D;  // 'm'
    assign fixed_string[9]  = 8'h65;  // 'e'
    assign fixed_string[10] = 8'h6E;  // 'n'
    assign fixed_string[11] = 8'h74;  // 't'
    assign fixed_string[12] = 8'h73;  // 's'
    assign fixed_string[13] = 8'h20;  // ' ' (space)
    assign fixed_string[14] = 8'h20;  // ' ' (space)

    // State transition logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start)
                    next_state = COUNT;
            end
            COUNT: begin
                if (counter == 4'd7)
                    next_state = FORMAT;
            end
            FORMAT: begin
                if (counter == 4'd7)
                    next_state = FINISH;
            end
            FINISH: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            counter <= 4'd0;
            odd_count <= 4'd0;
            odd_count_ascii <= 8'd0;
            done_reg <= 1'b0;
            // Initialize all outputs to 0
            out_0 <= 8'd0;
            out_1 <= 8'd0;
            out_2 <= 8'd0;
            out_3 <= 8'd0;
            out_4 <= 8'd0;
            out_5 <= 8'd0;
            out_6 <= 8'd0;
            out_7 <= 8'd0;
            out_8 <= 8'd0;
            out_9 <= 8'd0;
            out_10 <= 8'd0;
            out_11 <= 8'd0;
            out_12 <= 8'd0;
            out_13 <= 8'd0;
            out_14 <= 8'd0;
            out_15 <= 8'd0;
        end else begin
            done_reg <= 1'b0;
            case (state)
                IDLE: begin
                    if (start) begin
                        counter <= 4'd0;
                        odd_count <= 4'd0;
                    end
                end
                COUNT: begin
                    // Accumulate odd count over 8 cycles
                    if (is_odd[counter])
                        odd_count <= odd_count + 4'd1;
                    counter <= counter + 4'd1;
                end
                FORMAT: begin
                    // Convert count to ASCII and build output string over 8 cycles
                    if (counter == 4'd0) begin
                        // Position 0: count digit
                        out_0 <= count_to_ascii;
                        // Positions 1-7: first part of fixed string
                        out_1 <= fixed_string[0];
                        out_2 <= fixed_string[1];
                        out_3 <= fixed_string[2];
                        out_4 <= fixed_string[3];
                        out_5 <= fixed_string[4];
                        out_6 <= fixed_string[5];
                        out_7 <= fixed_string[6];
                    end else if (counter == 4'd1) begin
                        // Positions 8-15: remaining fixed string
                        out_8 <= fixed_string[7];
                        out_9 <= fixed_string[8];
                        out_10 <= fixed_string[9];
                        out_11 <= fixed_string[10];
                        out_12 <= fixed_string[11];
                        out_13 <= fixed_string[12];
                        out_14 <= fixed_string[13];
                        out_15 <= fixed_string[14];
                    end
                    counter <= counter + 4'd1;
                end
                FINISH: begin
                    done_reg <= 1'b1;
                end
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

    // Assign done output (synchronized to posedge of finish state)
    always @(*) begin
        done = done_reg;
    end

endmodule
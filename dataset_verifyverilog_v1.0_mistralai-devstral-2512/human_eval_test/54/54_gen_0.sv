module char_freq_check(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] s0_len,
    input wire [3:0] s1_len,
    input wire [7:0] s0_char_0,
    input wire [7:0] s0_char_1,
    input wire [7:0] s0_char_2,
    input wire [7:0] s0_char_3,
    input wire [7:0] s0_char_4,
    input wire [7:0] s0_char_5,
    input wire [7:0] s0_char_6,
    input wire [7:0] s0_char_7,
    input wire [7:0] s0_char_8,
    input wire [7:0] s0_char_9,
    input wire [7:0] s0_char_10,
    input wire [7:0] s0_char_11,
    input wire [7:0] s0_char_12,
    input wire [7:0] s0_char_13,
    input wire [7:0] s0_char_14,
    input wire [7:0] s0_char_15,
    input wire [7:0] s1_char_0,
    input wire [7:0] s1_char_1,
    input wire [7:0] s1_char_2,
    input wire [7:0] s1_char_3,
    input wire [7:0] s1_char_4,
    input wire [7:0] s1_char_5,
    input wire [7:0] s1_char_6,
    input wire [7:0] s1_char_7,
    input wire [7:0] s1_char_8,
    input wire [7:0] s1_char_9,
    input wire [7:0] s1_char_10,
    input wire [7:0] s1_char_11,
    input wire [7:0] s1_char_12,
    input wire [7:0] s1_char_13,
    input wire [7:0] s1_char_14,
    input wire [7:0] s1_char_15,
    output reg result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CHECK_LENGTH = 3'd1;
    localparam [2:0] COUNT_S0 = 3'd2;
    localparam [2:0] COUNT_S1 = 3'd3;
    localparam [2:0] COMPARE = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;

    reg [2:0] state, next_state;
    reg [7:0] char_index;
    reg [7:0] compare_index;
    reg [8:0] s0_histogram [0:255];
    reg [8:0] s1_histogram [0:255];
    reg [7:0] current_char;
    reg length_match;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Character arrays for easier access
    wire [7:0] s0_chars [0:15];
    wire [7:0] s1_chars [0:15];

    assign s0_chars[0] = s0_char_0;
    assign s0_chars[1] = s0_char_1;
    assign s0_chars[2] = s0_char_2;
    assign s0_chars[3] = s0_char_3;
    assign s0_chars[4] = s0_char_4;
    assign s0_chars[5] = s0_char_5;
    assign s0_chars[6] = s0_char_6;
    assign s0_chars[7] = s0_char_7;
    assign s0_chars[8] = s0_char_8;
    assign s0_chars[9] = s0_char_9;
    assign s0_chars[10] = s0_char_10;
    assign s0_chars[11] = s0_char_11;
    assign s0_chars[12] = s0_char_12;
    assign s0_chars[13] = s0_char_13;
    assign s0_chars[14] = s0_char_14;
    assign s0_chars[15] = s0_char_15;

    assign s1_chars[0] = s1_char_0;
    assign s1_chars[1] = s1_char_1;
    assign s1_chars[2] = s1_char_2;
    assign s1_chars[3] = s1_char_3;
    assign s1_chars[4] = s1_char_4;
    assign s1_chars[5] = s1_char_5;
    assign s1_chars[6] = s1_char_6;
    assign s1_chars[7] = s1_char_7;
    assign s1_chars[8] = s1_char_8;
    assign s1_chars[9] = s1_char_9;
    assign s1_chars[10] = s1_char_10;
    assign s1_chars[11] = s1_char_11;
    assign s1_chars[12] = s1_char_12;
    assign s1_chars[13] = s1_char_13;
    assign s1_chars[14] = s1_char_14;
    assign s1_chars[15] = s1_char_15;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            char_index <= 8'd0;
            compare_index <= 8'd0;
            length_match <= 1'b0;
            cycle_count <= 8'd0;

            // Initialize histograms
            integer i;
            for (i = 0; i < 256; i = i + 1) begin
                s0_histogram[i] <= 9'd0;
                s1_histogram[i] <= 9'd0;
            end
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 8'd1;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        next_state <= CHECK_LENGTH;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                CHECK_LENGTH: begin
                    if (s0_len == s1_len) begin
                        length_match <= 1'b1;
                        next_state <= COUNT_S0;
                    end else begin
                        length_match <= 1'b0;
                        result <= 1'b0;
                        next_state <= DONE_STATE;
                    end
                end

                COUNT_S0: begin
                    if (char_index < s0_len) begin
                        current_char <= s0_chars[char_index];
                        s0_histogram[current_char] <= s0_histogram[current_char] + 9'd1;
                        char_index <= char_index + 8'd1;
                        next_state <= COUNT_S0;
                    end else begin
                        char_index <= 8'd0;
                        next_state <= COUNT_S1;
                    end
                end

                COUNT_S1: begin
                    if (char_index < s1_len) begin
                        current_char <= s1_chars[char_index];
                        s1_histogram[current_char] <= s1_histogram[current_char] + 9'd1;
                        char_index <= char_index + 8'd1;
                        next_state <= COUNT_S1;
                    end else begin
                        char_index <= 8'd0;
                        compare_index <= 8'd0;
                        next_state <= COMPARE;
                    end
                end

                COMPARE: begin
                    if (compare_index < 8'd255) begin
                        if (s0_histogram[compare_index] != s1_histogram[compare_index]) begin
                            result <= 1'b0;
                            next_state <= DONE_STATE;
                        end else begin
                            compare_index <= compare_index + 8'd1;
                            next_state <= COMPARE;
                        end
                    end else begin
                        // Last comparison (index 255)
                        if (s0_histogram[255] == s1_histogram[255]) begin
                            result <= 1'b1;
                        end else begin
                            result <= 1'b0;
                        end
                        next_state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                    result <= 1'b0;
                end
            endcase
        end
    end

    // Safety: prevent infinite loops
    always @(posedge clk) begin
        if (cycle_count >= MAX_CYCLES) begin
            state <= IDLE;
            done <= 1'b1;
            result <= 1'b0;
            cycle_count <= 8'd0;
        end
    end

endmodule
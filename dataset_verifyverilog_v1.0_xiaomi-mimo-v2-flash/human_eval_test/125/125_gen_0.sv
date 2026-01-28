module string_processor (
    input clk,
    input rst_n,
    input start,
    input [7:0] char_data [0:15],
    input [3:0] str_len,
    output reg [1:0] result_type,
    output reg [15:0] result_val,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] SAMPLE     = 3'd1;
    localparam [2:0] SEARCH_WS  = 3'd2;
    localparam [2:0] SEARCH_COM = 3'd3;
    localparam [2:0] COUNT_LO   = 3'd4;
    localparam [2:0] OUTPUT     = 3'd5;
    localparam [2:0] FINISH     = 3'd6;

    // Internal registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [15:0] sampled_data [0:15];
    reg [3:0] sampled_len;
    reg [3:0] idx;
    reg [4:0] word_count;  // Use 5-bit to count up to 16
    reg found_marker;
    reg [15:0] bitmask;
    reg [3:0] lower_case_count;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_type <= 2'd0;
            result_val <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            idx <= 4'd0;
            word_count <= 5'd0;
            found_marker <= 1'b0;
            bitmask <= 16'd0;
            lower_case_count <= 4'd0;
            sampled_len <= 4'd0;
            // Initialize sampled_data array
            sampled_data[0] <= 16'd0;
            sampled_data[1] <= 16'd0;
            sampled_data[2] <= 16'd0;
            sampled_data[3] <= 16'd0;
            sampled_data[4] <= 16'd0;
            sampled_data[5] <= 16'd0;
            sampled_data[6] <= 16'd0;
            sampled_data[7] <= 16'd0;
            sampled_data[8] <= 16'd0;
            sampled_data[9] <= 16'd0;
            sampled_data[10] <= 16'd0;
            sampled_data[11] <= 16'd0;
            sampled_data[12] <= 16'd0;
            sampled_data[13] <= 16'd0;
            sampled_data[14] <= 16'd0;
            sampled_data[15] <= 16'd0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    idx <= 4'd0;
                    word_count <= 5'd0;
                    found_marker <= 1'b0;
                    bitmask <= 16'd0;
                    lower_case_count <= 4'd0;
                    if (start) begin
                        state <= SAMPLE;
                    end
                end

                SAMPLE: begin
                    // Sample all 16 bytes
                    case (idx)
                        4'd0:  sampled_data[0] <= char_data[0];
                        4'd1:  sampled_data[1] <= char_data[1];
                        4'd2:  sampled_data[2] <= char_data[2];
                        4'd3:  sampled_data[3] <= char_data[3];
                        4'd4:  sampled_data[4] <= char_data[4];
                        4'd5:  sampled_data[5] <= char_data[5];
                        4'd6:  sampled_data[6] <= char_data[6];
                        4'd7:  sampled_data[7] <= char_data[7];
                        4'd8:  sampled_data[8] <= char_data[8];
                        4'd9:  sampled_data[9] <= char_data[9];
                        4'd10: sampled_data[10] <= char_data[10];
                        4'd11: sampled_data[11] <= char_data[11];
                        4'd12: sampled_data[12] <= char_data[12];
                        4'd13: sampled_data[13] <= char_data[13];
                        4'd14: sampled_data[14] <= char_data[14];
                        4'd15: sampled_data[15] <= char_data[15];
                        default: sampled_data[0] <= 16'd0;
                    endcase
                    idx <= idx + 4'd1;
                    if (idx == 4'd15) begin
                        sampled_len <= str_len;
                        idx <= 4'd0;
                    end
                end

                SEARCH_WS: begin
                    if (idx < sampled_len) begin
                        if (sampled_data[idx] == 8'h20) begin  // Whitespace
                            found_marker <= 1'b1;
                            word_count <= idx + 5'd1;  // Position (1-indexed for odd/even)
                            bitmask[idx] <= 1'b1;
                        end else if (found_marker) begin
                            bitmask[idx] <= 1'b1;
                        end else begin
                            bitmask[idx] <= 1'b0;
                        end
                        idx <= idx + 4'd1;
                    end
                end

                SEARCH_COM: begin
                    if (idx < sampled_len) begin
                        if (sampled_data[idx] == 8'h2C) begin  // Comma
                            found_marker <= 1'b1;
                            word_count <= idx + 5'd1;  // Position (1-indexed)
                            bitmask[idx] <= 1'b1;
                        end else if (found_marker) begin
                            bitmask[idx] <= 1'b1;
                        end else begin
                            bitmask[idx] <= 1'b0;
                        end
                        idx <= idx + 4'd1;
                    end
                end

                COUNT_LO: begin
                    if (idx < sampled_len) begin
                        if (sampled_data[idx] >= 8'h61 && sampled_data[idx] <= 8'h7A) begin  // a-z
                            // Alphabet position = char - 'a'
                            // Odd if (char - 'a') % 2 == 1
                            if (sampled_data[idx][0]) begin  // Check LSB of (char - 'a')
                                lower_case_count <= lower_case_count + 4'd1;
                            end
                        end
                        idx <= idx + 4'd1;
                    end
                end

                OUTPUT: begin
                    if (!found_marker) begin  // No whitespace or comma found
                        result_val <= {12'd0, lower_case_count};
                        result_type <= lower_case_count[0] ? 2'b11 : 2'b10;
                    end else begin  // Found whitespace or comma
                        result_val <= bitmask;
                        // result_type based on position (1-indexed) odd/even
                        result_type <= word_count[0] ? 2'b01 : 2'b00;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                end
            endcase

            // Cycle counter for timeout
            if (start && state == IDLE) begin
                cycle_count <= 8'd0;
            end else if (state != IDLE && state != FINISH) begin
                cycle_count <= cycle_count + 8'd1;
            end
        end
    end

    // Combinational next state logic
    always @(*) begin
        next_state = state;  // Default stay in current state
        case (state)
            IDLE: begin
                if (start) next_state = SAMPLE;
                else next_state = IDLE;
            end

            SAMPLE: begin
                if (idx > 4'd15) next_state = SEARCH_WS;
                else next_state = SAMPLE;
            end

            SEARCH_WS: begin
                if (idx >= sampled_len) begin
                    if (found_marker) next_state = OUTPUT;
                    else next_state = SEARCH_COM;
                end else begin
                    next_state = SEARCH_WS;
                end
            end

            SEARCH_COM: begin
                if (idx >= sampled_len) begin
                    if (found_marker) next_state = OUTPUT;
                    else next_state = COUNT_LO;
                end else begin
                    next_state = SEARCH_COM;
                end
            end

            COUNT_LO: begin
                if (idx >= sampled_len) next_state = OUTPUT;
                else next_state = COUNT_LO;
            end

            OUTPUT: begin
                next_state = FINISH;
            end

            FINISH: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase

        // Timeout override
        if (cycle_count >= MAX_CYCLES && state != IDLE && state != FINISH) begin
            next_state = FINISH;
        end
    end

endmodule
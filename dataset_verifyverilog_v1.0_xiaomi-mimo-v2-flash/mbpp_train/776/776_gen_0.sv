module char_vowel_neighbor_counter (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] str [0:15],
    output reg [4:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] CAPTURE   = 3'd1;
    localparam [2:0] CHECK     = 3'd2;
    localparam [2:0] COUNT     = 3'd3;
    localparam [2:0] INCREMENT = 3'd4;
    localparam [2:0] FINISH    = 3'd5;

    // Internal registers
    reg [2:0] state, next_state;
    reg [3:0] idx;              // Position 0-15
    reg [4:0] count_reg;        // Accumulated count
    reg [7:0] captured_str [0:15]; // Latched input
    reg [7:0] current_char;
    reg [7:0] prev_char;
    reg [7:0] next_char;
    reg is_vowel_current;
    reg is_vowel_prev;
    reg is_vowel_next;
    reg should_count;

    // Vowel detection combinational logic
    always @(*) begin
        is_vowel_current = (captured_str[idx] == 8'h61) ||
                           (captured_str[idx] == 8'h65) ||
                           (captured_str[idx] == 8'h69) ||
                           (captured_str[idx] == 8'h6F) ||
                           (captured_str[idx] == 8'h75);
        
        if (idx > 0) begin
            prev_char = captured_str[idx - 4'd1];
            is_vowel_prev = (prev_char == 8'h61) ||
                            (prev_char == 8'h65) ||
                            (prev_char == 8'h69) ||
                            (prev_char == 8'h6F) ||
                            (prev_char == 8'h75);
        end else begin
            prev_char = 8'h00;
            is_vowel_prev = 1'b0;
        end

        if (idx < 15) begin
            next_char = captured_str[idx + 4'd1];
            is_vowel_next = (next_char == 8'h61) ||
                            (next_char == 8'h65) ||
                            (next_char == 8'h69) ||
                            (next_char == 8'h6F) ||
                            (next_char == 8'h75);
        end else begin
            next_char = 8'h00;
            is_vowel_next = 1'b0;
        end
    end

    // Neighbor check combinational logic
    always @(*) begin
        should_count = 1'b0;
        if (!is_vowel_current) begin
            if (idx == 0) begin
                // First position: only check next
                if (is_vowel_next) should_count = 1'b1;
            end else if (idx == 15) begin
                // Last position: only check previous
                if (is_vowel_prev) should_count = 1'b1;
            end else begin
                // Middle positions: check previous OR next
                if (is_vowel_prev || is_vowel_next) should_count = 1'b1;
            end
        end
    end

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 5'd0;
            done <= 1'b0;
            idx <= 4'd0;
            count_reg <= 5'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 5'd0;
                    idx <= 4'd0;
                    count_reg <= 5'd0;
                    if (start) begin
                        state <= CAPTURE;
                    end
                end

                CAPTURE: begin
                    // Latch input array in one cycle
                    captured_str[0] <= str[0];
                    captured_str[1] <= str[1];
                    captured_str[2] <= str[2];
                    captured_str[3] <= str[3];
                    captured_str[4] <= str[4];
                    captured_str[5] <= str[5];
                    captured_str[6] <= str[6];
                    captured_str[7] <= str[7];
                    captured_str[8] <= str[8];
                    captured_str[9] <= str[9];
                    captured_str[10] <= str[10];
                    captured_str[11] <= str[11];
                    captured_str[12] <= str[12];
                    captured_str[13] <= str[13];
                    captured_str[14] <= str[14];
                    captured_str[15] <= str[15];
                    state <= CHECK;
                end

                CHECK: begin
                    // Combinational logic evaluated, wait for result
                    state <= COUNT;
                end

                COUNT: begin
                    if (should_count) begin
                        state <= INCREMENT;
                    end else begin
                        state <= INCREMENT;
                    end
                end

                INCREMENT: begin
                    if (should_count) begin
                        count_reg <= count_reg + 5'd1;
                    end
                    
                    if (idx == 4'd15) begin
                        state <= FINISH;
                    end else begin
                        idx <= idx + 4'd1;
                        state <= CHECK;
                    end
                end

                FINISH: begin
                    result <= count_reg;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
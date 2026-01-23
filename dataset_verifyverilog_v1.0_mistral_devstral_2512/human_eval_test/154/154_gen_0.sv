module cycpattern_check(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] len,
    input wire [63:0] a,
    input wire [63:0] b,
    output reg result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CHECK_ROTATIONS = 3'd1;
    localparam [2:0] GET_ROTATED_B = 3'd2;
    localparam [2:0] SEARCH_A = 3'd3;
    localparam [2:0] COMPARE_CHARS = 3'd4;
    localparam [2:0] FINISH = 3'd5;

    // Internal registers
    reg [2:0] state, next_state;
    reg [3:0] rotation_idx;
    reg [3:0] a_idx;
    reg [3:0] char_idx;
    reg [7:0] rotated_b [0:7];
    reg match_found;
    reg [7:0] current_char_a;
    reg [7:0] current_char_b;

    // Rotation generation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            rotation_idx <= 4'd0;
            a_idx <= 4'd0;
            char_idx <= 4'd0;
            match_found <= 1'b0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = CHECK_ROTATIONS;
                end else begin
                    next_state = IDLE;
                end
            end

            CHECK_ROTATIONS: begin
                if (rotation_idx < len) begin
                    next_state = GET_ROTATED_B;
                end else begin
                    next_state = FINISH;
                end
            end

            GET_ROTATED_B: begin
                next_state = SEARCH_A;
            end

            SEARCH_A: begin
                if (a_idx <= (8'd8 - len)) begin
                    next_state = COMPARE_CHARS;
                end else begin
                    next_state = CHECK_ROTATIONS;
                end
            end

            COMPARE_CHARS: begin
                if (char_idx < len) begin
                    next_state = COMPARE_CHARS;
                end else begin
                    next_state = SEARCH_A;
                end
            end

            FINISH: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Rotation generation logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialization handled in state reset
        end else begin
            case (state)
                GET_ROTATED_B: begin
                    // Generate rotated B
                    for (integer i = 0; i < 8; i = i + 1) begin
                        if (i < len) begin
                            rotated_b[i] <= b[(rotation_idx + i) * 8 +: 8];
                        end else begin
                            rotated_b[i] <= 8'd0;
                        end
                    end
                end
            endcase
        end
    end

    // Search and compare logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialization handled in state reset
        end else begin
            case (state)
                SEARCH_A: begin
                    a_idx <= a_idx + 4'd1;
                    char_idx <= 4'd0;
                end

                COMPARE_CHARS: begin
                    current_char_a <= a[(a_idx + char_idx) * 8 +: 8];
                    current_char_b <= rotated_b[char_idx];

                    if (char_idx == 4'd0) begin
                        match_found <= 1'b1;
                    end

                    if (current_char_a != current_char_b) begin
                        match_found <= 1'b0;
                    end

                    char_idx <= char_idx + 4'd1;

                    if (char_idx == len && match_found) begin
                        result <= 1'b1;
                    end
                end

                CHECK_ROTATIONS: begin
                    rotation_idx <= rotation_idx + 4'd1;
                    a_idx <= 4'd0;
                end

                FINISH: begin
                    done <= 1'b1;
                end

                IDLE: begin
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule
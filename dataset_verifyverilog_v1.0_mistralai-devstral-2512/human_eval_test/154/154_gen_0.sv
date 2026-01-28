module rotation_substring_checker(
    input clk,
    input rst_n,
    input start,
    input [3:0] len_a,
    input [3:0] len_b,
    input [7:0] a [0:15],
    input [7:0] b [0:15],
    output reg result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CHECK_ROTATION = 3'd1;
    localparam [2:0] COMPARE = 3'd2;
    localparam [2:0] FINISH = 3'd3;

    reg [2:0] state, next_state;
    
    // Internal registers
    reg [3:0] rotation_count;
    reg [3:0] position_count;
    reg [3:0] char_count;
    reg [3:0] b_index;
    reg match_found;
    reg [7:0] current_b_char;
    reg [7:0] current_a_char;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            rotation_count <= 4'd0;
            position_count <= 4'd0;
            char_count <= 4'd0;
            b_index <= 4'd0;
            match_found <= 1'b0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = CHECK_ROTATION;
                    rotation_count = 4'd0;
                    position_count = 4'd0;
                    char_count = 4'd0;
                    match_found = 1'b0;
                end
            end

            CHECK_ROTATION: begin
                if (rotation_count < len_b) begin
                    next_state = COMPARE;
                    position_count = 4'd0;
                    char_count = 4'd0;
                end else begin
                    next_state = FINISH;
                end
            end

            COMPARE: begin
                if (char_count < len_b) begin
                    if (current_b_char == current_a_char) begin
                        char_count = char_count + 4'd1;
                        if (char_count == len_b) begin
                            match_found = 1'b1;
                            next_state = FINISH;
                        end
                    end else begin
                        next_state = CHECK_ROTATION;
                        rotation_count = rotation_count + 4'd1;
                    end
                end else begin
                    next_state = CHECK_ROTATION;
                    rotation_count = rotation_count + 4'd1;
                end
            end

            FINISH: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Character selection logic
    always @(*) begin
        case (state)
            COMPARE: begin
                b_index = (char_count + rotation_count) % len_b;
                current_b_char = b[b_index];
                current_a_char = a[position_count + char_count];
            end
            default: begin
                current_b_char = 8'd0;
                current_a_char = 8'd0;
            end
        endcase
    end

    // Position counter logic
    always @(*) begin
        if (state == COMPARE && char_count == 4'd0) begin
            if (position_count + len_b <= len_a) begin
                position_count = position_count + 4'd1;
            end else begin
                position_count = 4'd0;
            end
        end
    end

    // Output logic
    always @(*) begin
        result = 1'b0;
        done = 1'b0;
        case (state)
            FINISH: begin
                result = match_found;
                done = 1'b1;
            end
            default: begin
                result = 1'b0;
                done = 1'b0;
            end
        endcase
    end

endmodule
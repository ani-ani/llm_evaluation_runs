module char_processor(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] s_chars [0:15],
    input wire [7:0] c_chars [0:15],
    input wire [3:0] s_len,
    output reg [7:0] result_chars [0:15],
    output reg [3:0] result_len,
    output reg is_palindrome,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] SCAN_DELETE = 2'd1;
    localparam [1:0] CHECK_PALINDROME = 2'd2;
    localparam [1:0] FINISHED = 2'd3;

    reg [1:0] state, next_state;
    reg [3:0] s_index;
    reg [3:0] c_index;
    reg [3:0] result_index;
    reg [3:0] pal_check_index;
    reg [7:0] temp_result_chars [0:15];
    reg match_found;
    reg palindrome_valid;
    reg [7:0] i;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            s_index <= 4'd0;
            c_index <= 4'd0;
            result_index <= 4'd0;
            pal_check_index <= 4'd0;
            match_found <= 1'b0;
            palindrome_valid <= 1'b1;
            done <= 1'b0;
            is_palindrome <= 1'b0;
            result_len <= 4'd0;
            for (i = 0; i < 16; i = i + 1) begin
                temp_result_chars[i] <= 8'd0;
                result_chars[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    is_palindrome <= 1'b0;
                    if (start) begin
                        next_state <= SCAN_DELETE;
                        s_index <= 4'd0;
                        result_index <= 4'd0;
                        result_len <= 4'd0;
                        for (i = 0; i < 16; i = i + 1) begin
                            temp_result_chars[i] <= 8'd0;
                        end
                    end else begin
                        next_state <= IDLE;
                    end
                end

                SCAN_DELETE: begin
                    if (s_index < s_len) begin
                        match_found <= 1'b0;
                        c_index <= 4'd0;
                        next_state <= SCAN_DELETE;
                    end else begin
                        result_len <= result_index;
                        next_state <= CHECK_PALINDROME;
                        pal_check_index <= 4'd0;
                        palindrome_valid <= 1'b1;
                    end
                end

                CHECK_PALINDROME: begin
                    if (pal_check_index < (result_len + 4'd1) / 2) begin
                        if (temp_result_chars[pal_check_index] != temp_result_chars[result_len - 4'd1 - pal_check_index]) begin
                            palindrome_valid <= 1'b0;
                        end
                        next_state <= CHECK_PALINDROME;
                    end else begin
                        is_palindrome <= palindrome_valid;
                        next_state <= FINISHED;
                    end
                end

                FINISHED: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
        end
    end

    // Deletion logic
    always @(posedge clk) begin
        if (state == SCAN_DELETE && s_index < s_len) begin
            if (c_index < 16) begin
                if (s_chars[s_index] == c_chars[c_index] && !match_found) begin
                    match_found <= 1'b1;
                end
                c_index <= c_index + 4'd1;
            end else begin
                if (!match_found) begin
                    temp_result_chars[result_index] <= s_chars[s_index];
                    result_index <= result_index + 4'd1;
                end
                s_index <= s_index + 4'd1;
            end
        end
    end

    // Palindrome check logic
    always @(posedge clk) begin
        if (state == CHECK_PALINDROME && pal_check_index < (result_len + 4'd1) / 2) begin
            pal_check_index <= pal_check_index + 4'd1;
        end
    end

    // Output assignment
    always @(posedge clk) begin
        if (state == FINISHED) begin
            for (i = 0; i < 16; i = i + 1) begin
                result_chars[i] <= temp_result_chars[i];
            end
        end
    end

endmodule
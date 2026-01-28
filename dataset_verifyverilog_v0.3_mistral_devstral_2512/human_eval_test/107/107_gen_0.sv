module even_odd_palindrome(
    input clk,
    input rst_n,
    input start,
    input [9:0] n,
    output reg [9:0] even,
    output reg [9:0] odd,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] CHECKING  = 3'd1;
    localparam [2:0] COUNTING  = 3'd2;
    localparam [2:0] NEXT_NUM  = 3'd3;
    localparam [2:0] DONE      = 3'd4;

    // Internal signals
    reg [2:0] state, next_state;
    reg [9:0] current_num;
    reg [9:0] temp;
    reg [3:0] digit0, digit1, digit2;
    reg is_palindrome;
    reg increment_even, increment_odd;
    reg [9:0] cycle_count;
    localparam [9:0] MAX_CYCLES = 10'd3000;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            current_num <= 10'd0;
            temp <= 10'd0;
            digit0 <= 4'd0;
            digit1 <= 4'd0;
            digit2 <= 4'd0;
            is_palindrome <= 1'b0;
            increment_even <= 1'b0;
            increment_odd <= 1'b0;
            even <= 10'd0;
            odd <= 10'd0;
            done <= 1'b0;
            cycle_count <= 10'd0;
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 10'd1;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 10'd0;
                    if (start) begin
                        next_state <= CHECKING;
                        current_num <= 10'd1;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                CHECKING: begin
                    // Extract digits
                    temp <= current_num;
                    digit0 <= temp[3:0];
                    digit1 <= (temp >> 4)[3:0];
                    digit2 <= (temp >> 8)[3:0];

                    // Check if palindrome
                    if (current_num < 10) begin
                        // 1-digit numbers are always palindromes
                        is_palindrome <= 1'b1;
                    end else if (current_num < 100) begin
                        // 2-digit numbers: check if both digits equal
                        is_palindrome <= (digit0 == digit1);
                    end else if (current_num < 1000) begin
                        // 3-digit numbers: check if first and last digits equal
                        is_palindrome <= (digit0 == digit2);
                    end else begin
                        // 4-digit numbers: check if first and last digits equal, and middle two equal
                        is_palindrome <= (digit0 == (temp >> 12)[3:0]) && (digit1 == (temp >> 8)[3:0]);
                    end

                    if (is_palindrome) begin
                        if (current_num[0] == 1'b0) begin
                            increment_even <= 1'b1;
                            increment_odd <= 1'b0;
                        end else begin
                            increment_even <= 1'b0;
                            increment_odd <= 1'b1;
                        end
                        next_state <= COUNTING;
                    end else begin
                        next_state <= NEXT_NUM;
                    end
                end

                COUNTING: begin
                    if (increment_even) begin
                        even <= even + 10'd1;
                    end
                    if (increment_odd) begin
                        odd <= odd + 10'd1;
                    end
                    increment_even <= 1'b0;
                    increment_odd <= 1'b0;
                    next_state <= NEXT_NUM;
                end

                NEXT_NUM: begin
                    if (current_num >= n || cycle_count >= MAX_CYCLES) begin
                        next_state <= DONE;
                    end else begin
                        current_num <= current_num + 10'd1;
                        next_state <= CHECKING;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end
endmodule
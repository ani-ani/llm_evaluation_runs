module even_odd_palindrome (
    input clk,
    input rst_n,
    input start,
    input [9:0] n,
    output reg [9:0] even,
    output reg [9:0] odd,
    output reg done
);
    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CHECKING = 3'd1;
    localparam [2:0] COUNTING = 3'd2;
    localparam [2:0] NEXT_NUM = 3'd3;
    localparam [2:0] DONE = 3'd4;
    
    reg [2:0] state, next_state;
    reg [9:0] current_num;
    reg [9:0] temp_num;
    reg [3:0] digit_count;
    reg [3:0] is_palindrome;
    reg [3:0] inc_even;
    reg [3:0] inc_odd;
    reg [9:0] digits[0:9]; // Store up to 4 digits (max 1000)
    reg [3:0] digit_idx;
    reg [3:0] i;
    
    // FSM: State transitions
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = CHECKING;
                else
                    next_state = IDLE;
            end
            CHECKING: begin
                if (is_palindrome)
                    next_state = COUNTING;
                else
                    next_state = NEXT_NUM;
            end
            COUNTING: begin
                next_state = NEXT_NUM;
            end
            NEXT_NUM: begin
                if (current_num >= n)
                    next_state = DONE;
                else
                    next_state = CHECKING;
            end
            DONE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end
    
    // Main FSM sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_num <= 10'd0;
            even <= 10'd0;
            odd <= 10'd0;
            done <= 1'b0;
            temp_num <= 10'd0;
            digit_count <= 4'd0;
            is_palindrome <= 4'd0;
            inc_even <= 4'd0;
            inc_odd <= 4'd0;
            digit_idx <= 4'd0;
            for (i = 0; i < 10; i = i + 1) begin
                digits[i] <= 10'd0;
            end
        end else begin
            state <= next_state;
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    even <= even; // Hold value
                    odd <= odd; // Hold value
                    if (start) begin
                        current_num <= 10'd1;
                    end
                end
                
                CHECKING: begin
                    // Extract digits and check palindrome
                    temp_num <= current_num;
                    digit_count <= 4'd0;
                    is_palindrome <= 4'd0;
                    digit_idx <= 4'd0;
                    // Initialize digits array
                    for (i = 0; i < 10; i = i + 1) begin
                        digits[i] <= 10'd0;
                    end
                end
                
                COUNTING: begin
                    if (inc_even) begin
                        even <= even + 10'd1;
                    end
                    if (inc_odd) begin
                        odd <= odd + 10'd1;
                    end
                end
                
                NEXT_NUM: begin
                    current_num <= current_num + 10'd1;
                end
                
                DONE: begin
                    done <= 1'b1;
                end
                
                default: begin
                    current_num <= 10'd0;
                end
            endcase
        end
    end
    
    // Digit extraction and palindrome check logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            digit_count <= 4'd0;
            is_palindrome <= 4'd0;
            inc_even <= 4'd0;
            inc_odd <= 4'd0;
        end else if (state == CHECKING) begin
            // Extract digits
            if (digit_count < 4'd4) begin
                temp_num <= temp_num / 10'd10;
                digits[digit_count] <= temp_num % 10'd10;
                digit_count <= digit_count + 4'd1;
            end else begin
                // Check palindrome based on digit count
                if (digit_count == 4'd1) begin
                    // 1-digit numbers are always palindromes
                    is_palindrome <= 4'd1;
                    // Check parity
                    if (digits[0] % 2 == 0)
                        inc_even <= 4'd1;
                    else
                        inc_odd <= 4'd1;
                end else if (digit_count == 4'd2) begin
                    // 2-digit: check if both digits equal
                    if (digits[0] == digits[1]) begin
                        is_palindrome <= 4'd1;
                        if (digits[0] % 2 == 0)
                            inc_even <= 4'd1;
                        else
                            inc_odd <= 4'd1;
                    end else begin
                        is_palindrome <= 4'd0;
                        inc_even <= 4'd0;
                        inc_odd <= 4'd0;
                    end
                end else if (digit_count >= 4'd3) begin
                    // 3 or 4-digit: check first and last digits equal
                    if (digits[0] == digits[digit_count - 4'd1]) begin
                        is_palindrome <= 4'd1;
                        if (current_num % 2 == 0)
                            inc_even <= 4'd1;
                        else
                            inc_odd <= 4'd1;
                    end else begin
                        is_palindrome <= 4'd0;
                        inc_even <= 4'd0;
                        inc_odd <= 4'd0;
                    end
                end else begin
                    is_palindrome <= 4'd0;
                    inc_even <= 4'd0;
                    inc_odd <= 4'd0;
                end
            end
        end
    end
    
endmodule
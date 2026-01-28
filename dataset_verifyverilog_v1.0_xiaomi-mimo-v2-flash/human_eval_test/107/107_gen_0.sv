module palindrome_counter (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [9:0] n_in,
    output reg [8:0] even_count,
    output reg [8:0] odd_count,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE     = 3'd0;
    localparam [2:0] LOAD     = 3'd1;
    localparam [2:0] CHECK    = 3'd2;
    localparam [2:0] COUNT    = 3'd3;
    localparam [2:0] INCREMENT = 3'd4;
    localparam [2:0] COMPLETE = 3'd5;

    // Registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [9:0] current_num;
    reg [9:0] current_limit;
    reg [9:0] reversed_num;
    reg [3:0] digit_count;
    reg [3:0] digit_ptr;
    reg [9:0] temp_num;
    reg [3:0] digit;
    reg is_palindrome;
    reg [3:0] last_digit;
    reg start_delayed;

    // State transition and operations
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            even_count <= 9'd0;
            odd_count <= 9'd0;
            done <= 1'b0;
            current_num <= 10'd0;
            current_limit <= 10'd0;
            reversed_num <= 10'd0;
            digit_count <= 4'd0;
            digit_ptr <= 4'd0;
            temp_num <= 10'd0;
            digit <= 4'd0;
            is_palindrome <= 1'b0;
            last_digit <= 4'd0;
            start_delayed <= 1'b0;
        end else begin
            start_delayed <= start;
            state <= next_state;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start || start_delayed) begin
                        current_limit <= n_in;
                        current_num <= 10'd1;
                    end
                end

                LOAD: begin
                    // Initialize for digit extraction
                    temp_num <= current_num;
                    reversed_num <= 10'd0;
                    digit_count <= 4'd0;
                    digit_ptr <= 4'd0;
                    is_palindrome <= 1'b0;
                end

                CHECK: begin
                    // Extract digits and reverse
                    if (temp_num != 10'd0) begin
                        digit <= temp_num[3:0];  // Extract last digit
                        temp_num <= {6'd0, temp_num[9:4]};  // Divide by 10 (approx)
                        // Shift for division by 10 properly
                        temp_num <= temp_num / 10;
                        reversed_num <= (reversed_num * 10) + temp_num[3:0];
                        digit_count <= digit_count + 4'd1;
                    end
                end

                COUNT: begin
                    // Compare original and reversed
                    if (current_num == reversed_num) begin
                        is_palindrome <= 1'b1;
                        last_digit <= current_num[3:0];  // Last digit for parity
                    end else begin
                        is_palindrome <= 1'b0;
                    end
                end

                INCREMENT: begin
                    if (is_palindrome) begin
                        if (last_digit[0] == 1'b0) begin  // Even check
                            even_count <= even_count + 9'd1;
                        end else begin
                            odd_count <= odd_count + 9'd1;
                        end
                    end
                    current_num <= current_num + 10'd1;
                end

                COMPLETE: begin
                    done <= 1'b1;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start_delayed || start) begin
                    if (n_in >= 10'd1)
                        next_state = LOAD;
                    else
                        next_state = COMPLETE;
                end else begin
                    next_state = IDLE;
                end
            end

            LOAD: begin
                next_state = CHECK;
            end

            CHECK: begin
                if (temp_num == 10'd0)
                    next_state = COUNT;
                else
                    next_state = CHECK;
            end

            COUNT: begin
                next_state = INCREMENT;
            end

            INCREMENT: begin
                if (current_num >= current_limit)
                    next_state = COMPLETE;
                else
                    next_state = LOAD;
            end

            COMPLETE: begin
                next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule
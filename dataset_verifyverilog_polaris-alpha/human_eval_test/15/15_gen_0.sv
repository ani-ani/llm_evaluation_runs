module number_sequence (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        start,
    input  wire [3:0]  n,
    output reg  [7:0]  char_out,
    output reg         valid,
    output reg         done
);

    // State encoding
    localparam IDLE         = 2'b00;
    localparam OUTPUT_NUM   = 2'b01;
    localparam OUTPUT_SPACE = 2'b10;

    reg [1:0]  state, next_state;
    reg [3:0]  curr_num, next_curr_num;
    reg        ten_flag, next_ten_flag;   // Indicates whether to output tens digit
    reg        digit_sel, next_digit_sel; // 0: tens (when ten_flag=1), 1: ones

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= IDLE;
            curr_num   <= 4'd0;
            ten_flag   <= 1'b0;
            digit_sel  <= 1'b0;
            char_out   <= 8'd0;
            valid      <= 1'b0;
            done       <= 1'b0;
        end else begin
            state      <= next_state;
            curr_num   <= next_curr_num;
            ten_flag   <= next_ten_flag;
            digit_sel  <= next_digit_sel;
            char_out   <= (valid_next) ? char_next : 8'd0;
            valid      <= valid_next;
            done       <= done_next;
        end
    end

    // Combinational signals for next-state and outputs
    reg [7:0] char_next;
    reg       valid_next;
    reg       done_next;

    always @* begin
        // Default assignments
        next_state     = state;
        next_curr_num  = curr_num;
        next_ten_flag  = ten_flag;
        next_digit_sel = digit_sel;
        char_next      = 8'd0;
        valid_next     = 1'b0;
        done_next      = 1'b0;

        case (state)
            IDLE: begin
                // Wait for start pulse
                if (start) begin
                    next_curr_num  = 4'd0;
                    // Determine if first number has tens digit
                    next_ten_flag  = (4'd0 >= 4'd10) ? 1'b1 : 1'b0; // always 0 for 0..9
                    next_digit_sel = 1'b0; // start from tens if any
                    next_state     = OUTPUT_NUM;
                end
            end

            OUTPUT_NUM: begin
                // Output digit(s) of curr_num
                if (ten_flag && (digit_sel == 1'b0)) begin
                    // Tens digit
                    char_next  = 8'd49; // '1' for 10-15
                    valid_next = 1'b1;
                    // Next, output ones digit
                    next_digit_sel = 1'b1;
                    next_state     = OUTPUT_NUM;
                end else begin
                    // Ones digit (or single-digit number)
                    // Compute ones = curr_num % 10, works for 0-15
                    char_next  = 8'd48 + (curr_num % 10);
                    valid_next = 1'b1;

                    // Decide next step after finishing current number
                    if (curr_num == n) begin
                        // Last number completed
                        done_next  = 1'b1;
                        next_state = IDLE;
                    end else begin
                        // More numbers to come: output space next
                        next_state = OUTPUT_SPACE;
                    end

                    // Prepare for next number (values used after space state)
                    next_curr_num  = curr_num + 4'd1;
                    next_ten_flag  = ((curr_num + 4'd1) >= 4'd10) ? 1'b1 : 1'b0;
                    next_digit_sel = 1'b0; // start from tens if needed
                end
            end

            OUTPUT_SPACE: begin
                // Output single space between numbers (no trailing space after last)
                char_next  = 8'd32; // ' '
                valid_next = 1'b1;
                // After space, move to next number output
                next_state = OUTPUT_NUM;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule
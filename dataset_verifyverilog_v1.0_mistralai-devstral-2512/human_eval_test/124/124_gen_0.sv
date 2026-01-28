module DateValidator(
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input char_valid,
    input chars_done,
    output reg result,
    output reg done,
    output reg error
);

    // State declarations
    localparam [3:0] IDLE        = 4'd0;
    localparam [3:0] RECEIVING   = 4'd1;
    localparam [3:0] CHECK_FORMAT = 4'd2;
    localparam [3:0] PARSE_MONTH = 4'd3;
    localparam [3:0] PARSE_DAY   = 4'd4;
    localparam [3:0] PARSE_YEAR  = 4'd5;
    localparam [3:0] VALIDATE    = 4'd6;
    localparam [3:0] COMPLETE    = 4'd7;

    reg [3:0] state, next_state;
    reg [7:0] chars [0:9];
    reg [7:0] char_index;
    reg [7:0] cycle_count;
    reg [3:0] month, day;
    reg [11:0] year;
    reg [3:0] month_digits, day_digits;
    reg [11:0] year_digits;
    reg [7:0] i;
    reg format_valid, month_valid, day_valid, year_valid;

    localparam [7:0] ASCII_0 = 8'd48;
    localparam [7:0] ASCII_9 = 8'd57;
    localparam [7:0] ASCII_HYPHEN = 8'd45;
    localparam [7:0] MAX_CYCLES = 8'd255;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            error <= 1'b0;
            char_index <= 8'd0;
            cycle_count <= 8'd0;
            for (i = 0; i < 10; i = i + 1) begin
                chars[i] <= 8'd0;
            end
            month <= 4'd0;
            day <= 4'd0;
            year <= 12'd0;
            month_digits <= 4'd0;
            day_digits <= 4'd0;
            year_digits <= 12'd0;
            format_valid <= 1'b0;
            month_valid <= 1'b0;
            day_valid <= 1'b0;
            year_valid <= 1'b0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    error <= 1'b0;
                    result <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= RECEIVING;
                        char_index <= 8'd0;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                RECEIVING: begin
                    if (char_valid) begin
                        chars[char_index] <= char_in;
                        char_index <= char_index + 8'd1;
                    end
                    if (chars_done) begin
                        next_state <= CHECK_FORMAT;
                    end else begin
                        next_state <= RECEIVING;
                    end
                end

                CHECK_FORMAT: begin
                    cycle_count <= cycle_count + 8'd1;
                    format_valid <= 1'b1;
                    if (chars[2] != ASCII_HYPHEN || chars[5] != ASCII_HYPHEN) begin
                        format_valid <= 1'b0;
                    end
                    if (format_valid) begin
                        next_state <= PARSE_MONTH;
                    end else begin
                        next_state <= COMPLETE;
                    end
                end

                PARSE_MONTH: begin
                    cycle_count <= cycle_count + 8'd1;
                    month_digits[3:0] <= chars[0] - ASCII_0;
                    month_digits[7:4] <= chars[1] - ASCII_0;
                    month <= month_digits[7:4] * 4'd10 + month_digits[3:0];
                    next_state <= PARSE_DAY;
                end

                PARSE_DAY: begin
                    cycle_count <= cycle_count + 8'd1;
                    day_digits[3:0] <= chars[3] - ASCII_0;
                    day_digits[7:4] <= chars[4] - ASCII_0;
                    day <= day_digits[7:4] * 4'd10 + day_digits[3:0];
                    next_state <= PARSE_YEAR;
                end

                PARSE_YEAR: begin
                    cycle_count <= cycle_count + 8'd1;
                    year_digits[3:0] <= chars[6] - ASCII_0;
                    year_digits[7:4] <= chars[7] - ASCII_0;
                    year_digits[11:8] <= chars[8] - ASCII_0;
                    year_digits[15:12] <= chars[9] - ASCII_0;
                    year <= year_digits[15:12] * 12'd1000 + year_digits[11:8] * 12'd100 + year_digits[7:4] * 12'd10 + year_digits[3:0];
                    next_state <= VALIDATE;
                end

                VALIDATE: begin
                    cycle_count <= cycle_count + 8'd1;
                    month_valid <= (month >= 4'd1 && month <= 4'd12);
                    year_valid <= (year >= 12'd1000 && year <= 12'd9999);

                    case (month)
                        4'd1, 4'd3, 4'd5, 4'd7, 4'd8, 4'd10, 4'd12: day_valid <= (day >= 4'd1 && day <= 4'd31);
                        4'd4, 4'd6, 4'd9, 4'd11: day_valid <= (day >= 4'd1 && day <= 4'd30);
                        4'd2: day_valid <= (day >= 4'd1 && day <= 4'd29);
                        default: day_valid <= 1'b0;
                    endcase

                    if (month_valid && day_valid && year_valid) begin
                        result <= 1'b1;
                    end else begin
                        result <= 1'b0;
                    end
                    next_state <= COMPLETE;
                end

                COMPLETE: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (cycle_count >= MAX_CYCLES || !format_valid) begin
                        error <= 1'b1;
                    end
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                    error <= 1'b0;
                    result <= 1'b0;
                end
            endcase
        end
    end

endmodule
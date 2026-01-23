module date_validator(
    input clk,
    input rst_n,
    input start,
    input [7:0] char_0,
    input [7:0] char_1,
    input [7:0] char_2,
    input [7:0] char_3,
    input [7:0] char_4,
    input [7:0] char_5,
    input [7:0] char_6,
    input [7:0] char_7,
    input [7:0] char_8,
    input [7:0] char_9,
    output reg valid,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE          = 3'd0;
    localparam [2:0] PARSE         = 3'd1;
    localparam [2:0] CHECK_FORMAT  = 3'd2;
    localparam [2:0] VALIDATE_MONTH = 3'd3;
    localparam [2:0] VALIDATE_DAY  = 3'd4;
    localparam [2:0] DONE_STATE    = 3'd5;

    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Internal registers for parsed values
    reg [3:0] month_tens;
    reg [3:0] month_ones;
    reg [3:0] day_tens;
    reg [3:0] day_ones;
    reg [3:0] year_tens;
    reg [3:0] year_ones;
    reg [3:0] year_hundreds;
    reg [3:0] year_thousands;

    reg [3:0] month;
    reg [4:0] day;

    // ASCII constants
    localparam [7:0] ASCII_0 = 8'd48;
    localparam [7:0] ASCII_9 = 8'd57;
    localparam [7:0] ASCII_DASH = 8'd45;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            valid <= 1'b0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            month_tens <= 4'd0;
            month_ones <= 4'd0;
            day_tens <= 4'd0;
            day_ones <= 4'd0;
            year_tens <= 4'd0;
            year_ones <= 4'd0;
            year_hundreds <= 4'd0;
            year_thousands <= 4'd0;
            month <= 4'd0;
            day <= 5'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= PARSE;
                    end
                end

                PARSE: begin
                    // Parse month tens digit
                    if (char_0 >= ASCII_0 && char_0 <= ASCII_9) begin
                        month_tens <= char_0 - ASCII_0;
                    end else begin
                        month_tens <= 4'd0;
                    end

                    // Parse month ones digit
                    if (char_1 >= ASCII_0 && char_1 <= ASCII_9) begin
                        month_ones <= char_1 - ASCII_0;
                    end else begin
                        month_ones <= 4'd0;
                    end

                    // Parse day tens digit
                    if (char_3 >= ASCII_0 && char_3 <= ASCII_9) begin
                        day_tens <= char_3 - ASCII_0;
                    end else begin
                        day_tens <= 4'd0;
                    end

                    // Parse day ones digit
                    if (char_4 >= ASCII_0 && char_4 <= ASCII_9) begin
                        day_ones <= char_4 - ASCII_0;
                    end else begin
                        day_ones <= 4'd0;
                    end

                    // Parse year digits
                    if (char_6 >= ASCII_0 && char_6 <= ASCII_9) begin
                        year_thousands <= char_6 - ASCII_0;
                    end else begin
                        year_thousands <= 4'd0;
                    end

                    if (char_7 >= ASCII_0 && char_7 <= ASCII_9) begin
                        year_hundreds <= char_7 - ASCII_0;
                    end else begin
                        year_hundreds <= 4'd0;
                    end

                    if (char_8 >= ASCII_0 && char_8 <= ASCII_9) begin
                        year_tens <= char_8 - ASCII_0;
                    end else begin
                        year_tens <= 4'd0;
                    end

                    if (char_9 >= ASCII_0 && char_9 <= ASCII_9) begin
                        year_ones <= char_9 - ASCII_0;
                    end else begin
                        year_ones <= 4'd0;
                    end

                    state <= CHECK_FORMAT;
                end

                CHECK_FORMAT: begin
                    // Check dash positions
                    if (char_2 != ASCII_DASH || char_5 != ASCII_DASH) begin
                        valid <= 1'b0;
                        state <= DONE_STATE;
                    end
                    // Check all digit positions
                    else if (char_0 < ASCII_0 || char_0 > ASCII_9 ||
                             char_1 < ASCII_0 || char_1 > ASCII_9 ||
                             char_3 < ASCII_0 || char_3 > ASCII_9 ||
                             char_4 < ASCII_0 || char_4 > ASCII_9 ||
                             char_6 < ASCII_0 || char_6 > ASCII_9 ||
                             char_7 < ASCII_0 || char_7 > ASCII_9 ||
                             char_8 < ASCII_0 || char_8 > ASCII_9 ||
                             char_9 < ASCII_0 || char_9 > ASCII_9) begin
                        valid <= 1'b0;
                        state <= DONE_STATE;
                    end else begin
                        state <= VALIDATE_MONTH;
                    end
                end

                VALIDATE_MONTH: begin
                    // Convert month digits to binary
                    month <= month_tens * 4'd10 + month_ones;

                    // Check month range (1-12)
                    if (month < 4'd1 || month > 4'd12) begin
                        valid <= 1'b0;
                        state <= DONE_STATE;
                    end else begin
                        state <= VALIDATE_DAY;
                    end
                end

                VALIDATE_DAY: begin
                    // Convert day digits to binary
                    day <= day_tens * 5'd10 + day_ones;

                    // Check day range based on month
                    if (month == 4'd2) begin
                        // February: 1-29 days
                        if (day < 5'd1 || day > 5'd29) begin
                            valid <= 1'b0;
                        end else begin
                            valid <= 1'b1;
                        end
                    end
                    else if (month == 4'd4 || month == 4'd6 || month == 4'd9 || month == 4'd11) begin
                        // April, June, September, November: 1-30 days
                        if (day < 5'd1 || day > 5'd30) begin
                            valid <= 1'b0;
                        end else begin
                            valid <= 1'b1;
                        end
                    end
                    else begin
                        // All other months: 1-31 days
                        if (day < 5'd1 || day > 5'd31) begin
                            valid <= 1'b0;
                        end else begin
                            valid <= 1'b1;
                        end
                    end

                    state <= DONE_STATE;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule
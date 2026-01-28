module date_validator (
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
    localparam [2:0] VALIDATE_DAY   = 3'd4;
    localparam [2:0] DONE_STATE    = 3'd5;
    
    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd12;
    
    // Internal registers for parsed values
    reg [7:0] month_tens;
    reg [7:0] month_ones;
    reg [7:0] day_tens;
    reg [7:0] day_ones;
    reg [7:0] year_thousands;
    reg [7:0] year_hundreds;
    reg [7:0] year_tens;
    reg [7:0] year_ones;
    
    reg [7:0] month_binary;
    reg [7:0] day_binary;
    
    reg format_valid;
    reg month_valid;
    reg day_valid;
    
    // ASCII constants
    localparam [7:0] ASCII_DASH = 8'h2D;
    localparam [7:0] ASCII_0 = 8'h30;
    localparam [7:0] ASCII_9 = 8'h39;
    
    // Helper: check if character is digit
    wire is_digit;
    assign is_digit = (char_2 >= ASCII_0 && char_2 <= ASCII_9) ||
                     (char_5 >= ASCII_0 && char_5 <= ASCII_9) ||
                     (1'b0); // placeholder
    
    // Sequential logic for state transitions
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            valid <= 1'b0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            month_tens <= 8'd0;
            month_ones <= 8'd0;
            day_tens <= 8'd0;
            day_ones <= 8'd0;
            year_thousands <= 8'd0;
            year_hundreds <= 8'd0;
            year_tens <= 8'd0;
            year_ones <= 8'd0;
            month_binary <= 8'd0;
            day_binary <= 8'd0;
            format_valid <= 1'b0;
            month_valid <= 1'b0;
            day_valid <= 1'b0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        month_tens <= char_0;
                        month_ones <= char_1;
                        day_tens <= char_3;
                        day_ones <= char_4;
                        year_thousands <= char_6;
                        year_hundreds <= char_7;
                        year_tens <= char_8;
                        year_ones <= char_9;
                        format_valid <= 1'b1;
                        month_valid <= 1'b1;
                        day_valid <= 1'b1;
                    end
                end
                
                PARSE: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Convert to binary (already in registers)
                    // Calculate month: (month_tens - 48) * 10 + (month_ones - 48)
                    // Calculate day: (day_tens - 48) * 10 + (day_ones - 48)
                    month_binary <= (month_tens - ASCII_0) * 8'd10 + (month_ones - ASCII_0);
                    day_binary <= (day_tens - ASCII_0) * 8'd10 + (day_ones - ASCII_0);
                end
                
                CHECK_FORMAT: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Check positions 2 and 5 are dashes
                    // Check other positions are digits
                    if (char_2 != ASCII_DASH || char_5 != ASCII_DASH) begin
                        format_valid <= 1'b0;
                    end else if (char_0 < ASCII_0 || char_0 > ASCII_9) begin
                        format_valid <= 1'b0;
                    end else if (char_1 < ASCII_0 || char_1 > ASCII_9) begin
                        format_valid <= 1'b0;
                    end else if (char_3 < ASCII_0 || char_3 > ASCII_9) begin
                        format_valid <= 1'b0;
                    end else if (char_4 < ASCII_0 || char_4 > ASCII_9) begin
                        format_valid <= 1'b0;
                    end else if (char_6 < ASCII_0 || char_6 > ASCII_9) begin
                        format_valid <= 1'b0;
                    end else if (char_7 < ASCII_0 || char_7 > ASCII_9) begin
                        format_valid <= 1'b0;
                    end else if (char_8 < ASCII_0 || char_8 > ASCII_9) begin
                        format_valid <= 1'b0;
                    end else if (char_9 < ASCII_0 || char_9 > ASCII_9) begin
                        format_valid <= 1'b0;
                    end
                end
                
                VALIDATE_MONTH: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Check month is 01-12
                    if (month_binary < 8'd1 || month_binary > 8'd12) begin
                        month_valid <= 1'b0;
                    end
                end
                
                VALIDATE_DAY: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Check day based on month
                    if (month_binary == 8'd1 || month_binary == 8'd3 || month_binary == 8'd5 || 
                        month_binary == 8'd7 || month_binary == 8'd8 || month_binary == 8'd10 || 
                        month_binary == 8'd12) begin
                        // Months with 31 days
                        if (day_binary < 8'd1 || day_binary > 8'd31) begin
                            day_valid <= 1'b0;
                        end
                    end else if (month_binary == 8'd4 || month_binary == 8'd6 || 
                                month_binary == 8'd9 || month_binary == 8'd11) begin
                        // Months with 30 days
                        if (day_binary < 8'd1 || day_binary > 8'd30) begin
                            day_valid <= 1'b0;
                        end
                    end else if (month_binary == 8'd2) begin
                        // February - 29 days (allowing leap year)
                        if (day_binary < 8'd1 || day_binary > 8'd29) begin
                            day_valid <= 1'b0;
                        end
                    end else begin
                        day_valid <= 1'b0;
                    end
                    
                    // Set final valid signal
                    if (format_valid && month_valid && day_valid) begin
                        valid <= 1'b1;
                    end else begin
                        valid <= 1'b0;
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
    
    // Combinational next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = PARSE;
                end else begin
                    next_state = IDLE;
                end
            end
            
            PARSE: begin
                next_state = CHECK_FORMAT;
            end
            
            CHECK_FORMAT: begin
                next_state = VALIDATE_MONTH;
            end
            
            VALIDATE_MONTH: begin
                next_state = VALIDATE_DAY;
            end
            
            VALIDATE_DAY: begin
                if (cycle_count >= MAX_CYCLES) begin
                    next_state = DONE_STATE;
                end else begin
                    next_state = DONE_STATE;
                end
            end
            
            DONE_STATE: begin
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule
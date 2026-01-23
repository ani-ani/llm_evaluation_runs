module date_validator (
    input clk,
    input rst_n,
    input start,
    input [79:0] date_str,
    output reg valid,
    output reg done
);

    // State definition
    localparam IDLE = 5'b00001;
    localparam PARSE = 5'b00010;
    localparam CHECK_FORMAT = 5'b00100;
    localparam CHECK_MONTH = 5'b01000;
    localparam DONE = 5'b10000;

    reg [4:0] state, next_state;
    
    // Internal registers for parsed values
    reg [3:0] m1, m2, d1, d2, y1, y2, y3, y4;
    wire [7:0] char_m1, char_m2, char_d1, char_d2, char_sep1, char_sep2, char_y1, char_y2, char_y3, char_y4;
    
    // Extract characters from input string
    // String format: m1 m2 - d1 d2 - y1 y2 y3 y4
    assign char_m1 = date_str[7:0];
    assign char_m2 = date_str[15:8];
    assign char_sep1 = date_str[23:16];
    assign char_d1 = date_str[31:24];
    assign char_d2 = date_str[39:32];
    assign char_sep2 = date_str[47:40];
    assign char_y1 = date_str[55:48];
    assign char_y2 = date_str[63:56];
    assign char_y3 = date_str[71:64];
    assign char_y4 = date_str[79:72];

    // Validation flags
    reg valid_sep, valid_month, valid_day, valid_year;
    reg [4:0] month_val;
    reg [4:0] day_val;

    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = PARSE;
                else
                    next_state = IDLE;
            end
            PARSE: next_state = CHECK_FORMAT;
            CHECK_FORMAT: begin
                if (valid_sep && (m1 != 0 || m2 != 0)) // Also checks first digit validity implicitly
                    next_state = CHECK_MONTH;
                else
                    next_state = DONE;
            end
            CHECK_MONTH: begin
                if (valid_month)
                    next_state = CHECK_DAY; // Spec says CHECK_DAY state exists
                else
                    next_state = DONE;
            end
            CHECK_DAY: begin
                // Check DAY logic here or in separate logic?
                // Spec says state machine goes IDLE -> PARSE -> CHECK_FORMAT -> CHECK_MONTH -> CHECK_DAY -> DONE
                next_state = DONE;
            end
            DONE: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // Datapath and Output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid <= 0;
            done <= 0;
            valid_sep <= 0;
            valid_month <= 0;
            valid_day <= 0;
            valid_year <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    valid <= 0;
                end

                PARSE: begin
                    // Convert ASCII to binary (subtract 0x30)
                    // Check if characters are digits (0x30 - 0x39)
                    // If not digits, value will be out of 0-9 range, handled in CHECK_FORMAT
                    if (char_m1 >= 8'h30 && char_m1 <= 8'h39) 
                        m1 <= char_m1[3:0];
                    else 
                        m1 <= 4'hF; // Invalid marker
                        
                    if (char_m2 >= 8'h30 && char_m2 <= 8'h39) 
                        m2 <= char_m2[3:0];
                    else 
                        m2 <= 4'hF;
                        
                    if (char_d1 >= 8'h30 && char_d1 <= 8'h39) 
                        d1 <= char_d1[3:0];
                    else 
                        d1 <= 4'hF;
                        
                    if (char_d2 >= 8'h30 && char_d2 <= 8'h39) 
                        d2 <= char_d2[3:0];
                    else 
                        d2 <= 4'hF;
                        
                    if (char_y1 >= 8'h30 && char_y1 <= 8'h39) 
                        y1 <= char_y1[3:0];
                    else 
                        y1 <= 4'hF;
                        
                    if (char_y2 >= 8'h30 && char_y2 <= 8'h39) 
                        y2 <= char_y2[3:0];
                    else 
                        y2 <= 4'hF;
                        
                    if (char_y3 >= 8'h30 && char_y3 <= 8'h39) 
                        y3 <= char_y3[3:0];
                    else 
                        y3 <= 4'hF;
                        
                    if (char_y4 >= 8'h30 && char_y4 <= 8'h39) 
                        y4 <= char_y4[3:0];
                    else 
                        y4 <= 4'hF;
                end

                CHECK_FORMAT: begin
                    // Check separators are '-' (0x2D)
                    if (char_sep1 == 8'h2D && char_sep2 == 8'h2D && 
                        m1 <= 9 && m2 <= 9 && d1 <= 9 && d2 <= 9 && 
                        y1 <= 9 && y2 <= 9 && y3 <= 9 && y4 <= 9) begin
                        valid_sep <= 1;
                    end else begin
                        valid_sep <= 0;
                    end
                end

                CHECK_MONTH: begin
                    // Month 01-12. m1 is tens, m2 is ones.
                    // Valid range: 01 (binary 1) to 12 (binary 12)
                    // If m1 is 0, m2 must be 1-9
                    // If m1 is 1, m2 must be 0-2
                    // m1 cannot be > 1
                    
                    month_val <= {m1, m2}; // Combine to 8-bit or 5-bit for comparison
                    
                    if (m1 == 0 && m2 >= 1 && m2 <= 9) valid_month <= 1;
                    else if (m1 == 1 && m2 >= 0 && m2 <= 2) valid_month <= 1;
                    else valid_month <= 0;
                end

                CHECK_DAY: begin
                    // Day validation based on month
                    // If invalid month, we shouldn't be here if we followed strict FSM, but safe to check
                    // month_val is from previous stage
                    
                    day_val <= {d1, d2};
                    
                    // Assume valid_month is high if we are here (per FSM flow)
                    // However, let's make logic robust
                    
                    // Logic for day:
                    // 1,3,5,7,8,10,12 -> 01-31
                    // 4,6,9,11 -> 01-30
                    // 2 -> 01-29
                    
                    // Check if day is valid ASCII digits (already checked in PARSE/CHECK_FORMAT)
                    // Now check numeric range
                    
                    // Days 01-09: d1=0, d2=1..9 (Always valid if month is valid?) No, need range check
                    // Days 10-19: d1=1, d2=0..9
                    // Days 20-29: d1=2, d2=0..9
                    // Days 30-31: d1=3, d2=0..1
                    
                    // Simplified range check logic for 00-99 range vs max day
                    // Max day depends on month
                    
                    valid <= 0; // Reset valid initially, will be set at DONE
                    done <= 1;
                    
                    if (valid_sep && valid_month) begin
                        // Only check day if format and month are good
                        
                        case (month_val)
                            5'd1, 5'd3, 5'd5, 5'd7, 5'd8, 5'd10, 5'd12: begin
                                // 01-31
                                // d1 can be 0, 1, 2, 3
                                if (d1 <= 3) begin
                                    if (d1 < 3) valid <= 1; // 00-29 is valid for 31-day months (00 is technically invalid date, but spec says 01-31, so 00 invalid)
                                    else if (d1 == 3 && d2 <= 1) valid <= 1; // 30, 31
                                    else valid <= 0;
                                end else valid <= 0;
                                
                                // Spec says 01-31. 00 is invalid.
                                if (d1 == 0 && d2 == 0) valid <= 0;
                            end
                            5'd4, 5'd6, 5'd9, 5'd11: begin
                                // 01-30
                                if (d1 <= 3) begin
                                    if (d1 < 3) valid <= 1; // 00-29 (excluding 00)
                                    else if (d1 == 3 && d2 == 0) valid <= 1; // 30
                                    else valid <= 0;
                                end else valid <= 0;
                                if (d1 == 0 && d2 == 0) valid <= 0;
                            end
                            5'd2: begin
                                // 01-29 (leap year not required)
                                if (d1 <= 2) begin
                                    if (d1 < 2) valid <= 1; // 00-19
                                    else if (d1 == 2 && d2 <= 9) valid <= 1; // 20-29
                                    else valid <= 0;
                                end else valid <= 0;
                                if (d1 == 0 && d2 == 0) valid <= 0;
                            end
                            default: valid <= 0; // Month was invalid (shouldn't happen if FSM logic holds, but good to have)
                        endcase
                    end else begin
                        valid <= 0;
                    end
                    
                    // Year check: Spec says any 4-digit year is accepted. 
                    // Since we parsed them and checked they are digits, we are good.
                    // No separate year state required by FSM description (CHECK_DAY -> DONE), 
                    // but spec says "Check year (yyyy): any 4-digit year is accepted".
                    // If CHECK_DAY is the last validation step, we include year validity here implicitly 
                    // because if we reached here, we already verified they are digits (in PARSE/CHECK_FORMAT).
                end

                DONE: begin
                    done <= 0; // Handshake: Pulse done high for 1 cycle
                end
            endcase
        end
    end

endmodule
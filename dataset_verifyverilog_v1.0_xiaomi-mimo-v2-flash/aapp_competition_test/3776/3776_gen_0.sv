module time_finder (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire format,
    input wire [3:0] broken_h1,
    input wire [3:0] broken_h0,
    input wire [3:0] broken_m1,
    input wire [3:0] broken_m0,
    output reg [3:0] correct_h1,
    output reg [3:0] correct_h0,
    output reg [3:0] correct_m1,
    output reg [3:0] correct_m0,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] SETUP_H   = 3'd1;
    localparam [2:0] SETUP_M   = 3'd2;
    localparam [2:0] COMPARE   = 3'd3;
    localparam [2:0] UPDATE    = 3'd4;
    localparam [2:0] OUTPUT    = 3'd5;

    // Internal registers
    reg [2:0] state, next_state;
    reg [4:0] hour_reg;        // 0-23 or 1-12
    reg [5:0] minute_reg;      // 0-59
    reg [4:0] best_h;
    reg [5:0] best_m;
    reg [3:0] best_error;
    reg [3:0] current_error;
    reg [11:0] cycle_counter;  // Max 1440 iterations + overhead
    
    // Temporary digit registers for comparison
    reg [3:0] cand_h1, cand_h0, cand_m1, cand_m0;
    
    // Helper signals for digit extraction
    reg [3:0] digit_h1, digit_h0, digit_m1, digit_m0;
    
    // State transition and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            correct_h1 <= 4'd0;
            correct_h0 <= 4'd0;
            correct_m1 <= 4'd0;
            correct_m0 <= 4'd0;
            hour_reg <= 5'd0;
            minute_reg <= 6'd0;
            best_h <= 5'd0;
            best_m <= 6'd0;
            best_error <= 4'd15;
            current_error <= 4'd0;
            cycle_counter <= 12'd0;
            cand_h1 <= 4'd0;
            cand_h0 <= 4'd0;
            cand_m1 <= 4'd0;
            cand_m0 <= 4'd0;
            digit_h1 <= 4'd0;
            digit_h0 <= 4'd0;
            digit_m1 <= 4'd0;
            digit_m0 <= 4'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_counter <= 12'd0;
                    if (start) begin
                        best_error <= 4'd15;  // Initialize to max possible error
                        best_h <= 5'd0;
                        best_m <= 6'd0;
                        if (format) begin
                            hour_reg <= 5'd1;  // 12-hour starts at 1
                        end else begin
                            hour_reg <= 5'd0;  // 24-hour starts at 0
                        end
                        minute_reg <= 6'd0;
                    end
                end
                
                SETUP_H: begin
                    // Convert hour to digits
                    digit_h1 <= hour_reg / 5'd10;
                    digit_h0 <= hour_reg % 5'd10;
                    minute_reg <= 6'd0;  // Reset minutes for new hour
                end
                
                SETUP_M: begin
                    // Convert minute to digits
                    digit_m1 <= minute_reg / 6'd10;
                    digit_m0 <= minute_reg % 6'd10;
                end
                
                COMPARE: begin
                    // Calculate error for this candidate
                    current_error <= 4'd0;
                    cand_h1 <= digit_h1;
                    cand_h0 <= digit_h0;
                    cand_m1 <= digit_m1;
                    cand_m0 <= digit_m0;
                end
                
                UPDATE: begin
                    // Accumulate error count
                    current_error <= current_error + 
                        ((digit_h1 != broken_h1) ? 4'd1 : 4'd0) +
                        ((digit_h0 != broken_h0) ? 4'd1 : 4'd0) +
                        ((digit_m1 != broken_m1) ? 4'd1 : 4'd0) +
                        ((digit_m0 != broken_m0) ? 4'd1 : 4'd0);
                    
                    cycle_counter <= cycle_counter + 12'd1;
                    
                    // Check if this is the best so far
                    if ((cycle_counter == 12'd0) || (current_error < best_error)) begin
                        best_error <= current_error;
                        best_h <= hour_reg;
                        best_m <= minute_reg;
                    end
                    
                    // Increment minute
                    if (minute_reg < 6'd59) begin
                        minute_reg <= minute_reg + 6'd1;
                    end else begin
                        minute_reg <= 6'd0;
                        // Increment hour
                        if (format) begin
                            if (hour_reg < 5'd12) begin
                                hour_reg <= hour_reg + 5'd1;
                            end else begin
                                hour_reg <= 5'd1;  // Loop back to 1
                            end
                        end else begin
                            if (hour_reg < 5'd23) begin
                                hour_reg <= hour_reg + 5'd1;
                            end else begin
                                hour_reg <= 5'd0;  // Loop back to 0
                            end
                        end
                    end
                end
                
                OUTPUT: begin
                    // Convert best_h and best_m back to digits
                    correct_h1 <= best_h / 5'd10;
                    correct_h0 <= best_h % 5'd10;
                    correct_m1 <= best_m / 6'd10;
                    correct_m0 <= best_m % 6'd10;
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
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = SETUP_H;
                end
            end
            
            SETUP_H: begin
                next_state = SETUP_M;
            end
            
            SETUP_M: begin
                next_state = COMPARE;
            end
            
            COMPARE: begin
                next_state = UPDATE;
            end
            
            UPDATE: begin
                // Check termination conditions
                if (format) begin
                    // 12-hour: hour 1-12, minute 0-59
                    if (hour_reg == 5'd12 && minute_reg == 6'd59) begin
                        next_state = OUTPUT;
                    end else begin
                        next_state = SETUP_H;  // Loop for next iteration
                    end
                end else begin
                    // 24-hour: hour 0-23, minute 0-59
                    if (hour_reg == 5'd23 && minute_reg == 6'd59) begin
                        next_state = OUTPUT;
                    end else begin
                        next_state = SETUP_H;  // Loop for next iteration
                    end
                end
            end
            
            OUTPUT: begin
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule
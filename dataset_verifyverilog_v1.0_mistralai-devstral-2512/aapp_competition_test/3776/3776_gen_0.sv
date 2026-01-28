module min_digit_changes(
    input clk,
    input rst_n,
    input start,
    input format,
    input [3:0] broken_h1,
    input [3:0] broken_h0,
    input [3:0] broken_m1,
    input [3:0] broken_m0,
    output reg [3:0] correct_h1,
    output reg [3:0] correct_h0,
    output reg [3:0] correct_m1,
    output reg [3:0] correct_m0,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] SETUP_H   = 3'd1;
    localparam [2:0] SETUP_M   = 3'd2;
    localparam [2:0] COMPARE   = 3'd3;
    localparam [2:0] UPDATE    = 3'd4;
    localparam [2:0] OUTPUT    = 3'd5;

    // Internal registers
    reg [2:0] state;
    reg [4:0] hour_counter;      // 0-23
    reg [5:0] minute_counter;    // 0-59
    reg [3:0] best_error;        // 0-4
    reg [4:0] best_hour;         // 0-23
    reg [5:0] best_minute;       // 0-59
    reg [3:0] candidate_h1, candidate_h0, candidate_m1, candidate_m0;
    reg [3:0] error_count;
    reg [7:0] cycle_count;       // Prevent infinite loops
    localparam [7:0] MAX_CYCLES = 8'd2000;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            hour_counter <= 5'd0;
            minute_counter <= 6'd0;
            best_error <= 4'd4;
            best_hour <= 5'd0;
            best_minute <= 6'd0;
            correct_h1 <= 4'd0;
            correct_h0 <= 4'd0;
            correct_m1 <= 4'd0;
            correct_m0 <= 4'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= SETUP_H;
                        hour_counter <= 5'd0;
                        minute_counter <= 6'd0;
                        best_error <= 4'd4;
                        best_hour <= 5'd0;
                        best_minute <= 6'd0;
                    end
                end

                SETUP_H: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= OUTPUT;
                    end else begin
                        // Skip hour 0 for 12-hour format
                        if (format && hour_counter == 5'd0) begin
                            hour_counter <= 5'd1;
                        end else begin
                            // Generate candidate hour digits
                            candidate_h1 <= hour_counter[3:0];
                            candidate_h0 <= hour_counter[2:0];
                            state <= SETUP_M;
                        end
                    end
                end

                SETUP_M: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= OUTPUT;
                    end else begin
                        // Generate candidate minute digits
                        candidate_m1 <= minute_counter[3:0];
                        candidate_m0 <= minute_counter[2:0];
                        state <= COMPARE;
                    end
                end

                COMPARE: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= OUTPUT;
                    end else begin
                        // Calculate error count
                        error_count <= (candidate_h1 != broken_h1) + 
                                     (candidate_h0 != broken_h0) + 
                                     (candidate_m1 != broken_m1) + 
                                     (candidate_m0 != broken_m0);
                        state <= UPDATE;
                    end
                end

                UPDATE: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= OUTPUT;
                    end else begin
                        // Update best if current error is better
                        if (error_count < best_error) begin
                            best_error <= error_count;
                            best_hour <= hour_counter;
                            best_minute <= minute_counter;
                        end
                        // Move to next minute
                        if (minute_counter == 6'd59) begin
                            minute_counter <= 6'd0;
                            // Move to next hour
                            if (format && hour_counter == 5'd12) begin
                                state <= OUTPUT;
                            end else if (!format && hour_counter == 5'd23) begin
                                state <= OUTPUT;
                            end else begin
                                hour_counter <= hour_counter + 5'd1;
                                state <= SETUP_H;
                            end
                        end else begin
                            minute_counter <= minute_counter + 6'd1;
                            state <= SETUP_M;
                        end
                    end
                end

                OUTPUT: begin
                    done <= 1'b1;
                    // Output best time digits
                    correct_h1 <= best_hour[3:0];
                    correct_h0 <= best_hour[2:0];
                    correct_m1 <= best_minute[3:0];
                    correct_m0 <= best_minute[2:0];
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule
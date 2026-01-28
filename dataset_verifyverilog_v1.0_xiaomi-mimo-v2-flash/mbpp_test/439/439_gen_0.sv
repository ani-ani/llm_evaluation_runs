module multiple_to_single (
    input clk,
    input rst_n,
    input start,
    input [7:0] input_integers [0:7],
    input [3:0] len,
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] LOAD    = 3'd1;
    localparam [2:0] CALC    = 3'd2;
    localparam [2:0] MULT    = 3'd3;
    localparam [2:0] ADD     = 3'd4;
    localparam [2:0] FINISH  = 3'd5;
    localparam [2:0] ERROR   = 3'd6;

    // Internal registers
    reg [2:0] state;
    reg [3:0] idx;
    reg [31:0] accumulator;
    reg [31:0] multiplier;
    reg [31:0] temp_abs;
    reg sign_flag;
    reg processing_sign;
    reg [3:0] cycle_count;
    reg [2:0] digit_count;

    // Combinational logic for digit counting
    wire [31:0] abs_val;
    wire is_negative;
    wire [2:0] num_digits;
    
    assign is_negative = input_integers[idx][7];
    assign abs_val = is_negative ? (~input_integers[idx] + 32'd1) : {24'd0, input_integers[idx]};
    assign num_digits = (abs_val < 10'd10) ? 3'd1 : 3'd2;

    // Powers of 10 lookup
    reg [31:0] power_of_10;
    always @(*) begin
        case (digit_count)
            3'd1: power_of_10 = 32'd10;
            3'd2: power_of_10 = 32'd100;
            3'd3: power_of_10 = 32'd1000;
            3'd4: power_of_10 = 32'd10000;
            3'd5: power_of_10 = 32'd100000;
            3'd6: power_of_10 = 32'd1000000;
            3'd7: power_of_10 = 32'd10000000;
            default: power_of_10 = 32'd1;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            idx <= 4'd0;
            accumulator <= 32'd0;
            multiplier <= 32'd0;
            temp_abs <= 32'd0;
            sign_flag <= 1'b0;
            processing_sign <= 1'b0;
            cycle_count <= 4'd0;
            digit_count <= 3'd0;
        end else begin
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= LOAD;
                        idx <= 4'd0;
                        accumulator <= 32'd0;
                        sign_flag <= 1'b0;
                        processing_sign <= 1'b1;
                        cycle_count <= 4'd0;
                    end
                end

                LOAD: begin
                    if (idx < len && len <= 4'd8) begin
                        // Determine if negative for sign logic
                        if (processing_sign) begin
                            if (input_integers[idx][7]) begin
                                sign_flag <= 1'b1;
                            end
                            processing_sign <= 1'b0;
                        end

                        // Get absolute value
                        if (input_integers[idx][7]) begin
                            temp_abs <= (~input_integers[idx] + 32'd1);
                        end else begin
                            temp_abs <= {24'd0, input_integers[idx]};
                        end

                        // Determine digits
                        if ({24'd0, input_integers[idx][6:0]} < 7'd10) begin
                            digit_count <= 3'd1;
                            multiplier <= 32'd10;
                        end else begin
                            digit_count <= 3'd2;
                            multiplier <= 32'd100;
                        end

                        state <= CALC;
                    end else begin
                        // All done processing
                        if (sign_flag) begin
                            result <= -accumulator;
                        end else begin
                            result <= accumulator;
                        end
                        state <= FINISH;
                    end
                end

                CALC: begin
                    // Apply multiplier shift-add logic
                    // If accumulator is 0 (first element), no multiplication needed
                    if (accumulator == 32'd0) begin
                        state <= ADD;
                    end else begin
                        state <= MULT;
                    end
                end

                MULT: begin
                    // Multiply accumulator by multiplier (10 or 100)
                    // Since multiplier is small (10, 100), simple repeated addition works
                    // Optimization: Use shift-add for powers of 10
                    // 10 = 8 + 2
                    // 100 = 64 + 32 + 4
                    // Simple implementation: accumulator = accumulator * multiplier
                    // For synthesis efficiency with small constants:
                    if (multiplier == 32'd10) begin
                        accumulator <= (accumulator << 3) + (accumulator << 1);
                    end else begin // 100
                        accumulator <= (accumulator << 6) + (accumulator << 5) + (accumulator << 2);
                    end
                    state <= ADD;
                end

                ADD: begin
                    accumulator <= accumulator + temp_abs;
                    idx <= idx + 4'd1;
                    cycle_count <= cycle_count + 4'd1;
                    
                    if (cycle_count >= 4'd14) begin // Safety timeout (14 cycles max needed)
                        state <= ERROR;
                    end else begin
                        state <= LOAD;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                ERROR: begin
                    result <= 32'hDEADBEEF;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule
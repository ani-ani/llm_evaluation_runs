module PythagoreanRightAngleDetector(
    input clk,
    input rst_n,
    input start,
    input [15:0] side_a,
    input [15:0] side_b,
    input [15:0] side_c,
    output reg result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] LOAD      = 3'd1;
    localparam [2:0] PERM_1    = 3'd2;
    localparam [2:0] PERM_2    = 3'd3;
    localparam [2:0] PERM_3    = 3'd4;
    localparam [2:0] FINISH    = 3'd5;

    // Registers
    reg [2:0] state, next_state;
    reg [15:0] reg_a, reg_b, reg_c;
    reg [31:0] x_sq, y_sq, sum_sq, z_sq, diff;
    reg [31:0] abs_diff;
    reg valid_1, valid_2, valid_3;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd50;

    // State register and reset
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            reg_a <= 16'd0;
            reg_b <= 16'd0;
            reg_c <= 16'd0;
            x_sq <= 32'd0;
            y_sq <= 32'd0;
            sum_sq <= 32'd0;
            z_sq <= 32'd0;
            diff <= 32'd0;
            abs_diff <= 32'd0;
            valid_1 <= 1'b0;
            valid_2 <= 1'b0;
            valid_3 <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
            if (start) begin
                cycle_count <= 8'd0;
            end else begin
                cycle_count <= cycle_count + 8'd1;
            end
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = LOAD;
            end
            LOAD: begin
                next_state = PERM_1;
            end
            PERM_1: begin
                if (cycle_count >= 8'd3) next_state = PERM_2;
            end
            PERM_2: begin
                if (cycle_count >= 8'd6) next_state = PERM_3;
            end
            PERM_3: begin
                if (cycle_count >= 8'd9) next_state = FINISH;
            end
            FINISH: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Output logic and computation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 1'b0;
            done <= 1'b0;
            reg_a <= 16'd0;
            reg_b <= 16'd0;
            reg_c <= 16'd0;
            x_sq <= 32'd0;
            y_sq <= 32'd0;
            sum_sq <= 32'd0;
            z_sq <= 32'd0;
            diff <= 32'd0;
            abs_diff <= 32'd0;
            valid_1 <= 1'b0;
            valid_2 <= 1'b0;
            valid_3 <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                end
                
                LOAD: begin
                    reg_a <= side_a;
                    reg_b <= side_b;
                    reg_c <= side_c;
                    valid_1 <= 1'b0;
                    valid_2 <= 1'b0;
                    valid_3 <= 1'b0;
                end
                
                PERM_1: begin
                    // Cycle 1: Compute x^2 (reg_a * reg_a)
                    if (cycle_count == 8'd0) begin
                        x_sq <= reg_a * reg_a;
                        y_sq <= reg_b * reg_b;
                    end
                    // Cycle 2: Shift and add
                    else if (cycle_count == 8'd1) begin
                        sum_sq <= (x_sq[23:8] + y_sq[23:8]);
                    end
                    // Cycle 2: Compute z^2 (reg_c * reg_c)
                    else if (cycle_count == 8'd1) begin
                        z_sq <= reg_c * reg_c;
                    end
                    // Cycle 3: Compute difference and check
                    else if (cycle_count == 8'd2) begin
                        if (sum_sq >= z_sq[23:8]) begin
                            diff <= sum_sq - z_sq[23:8];
                        end else begin
                            diff <= z_sq[23:8] - sum_sq;
                        end
                    end
                    // Cycle 4: Check tolerance
                    else if (cycle_count == 8'd3) begin
                        if (diff <= 32'd16) begin
                            valid_1 <= 1'b1;
                        end
                    end
                end
                
                PERM_2: begin
                    // Cycle 1: Compute x^2 (reg_a * reg_a)
                    if (cycle_count == 8'd4) begin
                        x_sq <= reg_a * reg_a;
                        y_sq <= reg_c * reg_c;
                    end
                    // Cycle 2: Shift and add
                    else if (cycle_count == 8'd5) begin
                        sum_sq <= (x_sq[23:8] + y_sq[23:8]);
                    end
                    // Cycle 2: Compute z^2 (reg_b * reg_b)
                    else if (cycle_count == 8'd5) begin
                        z_sq <= reg_b * reg_b;
                    end
                    // Cycle 3: Compute difference
                    else if (cycle_count == 8'd6) begin
                        if (sum_sq >= z_sq[23:8]) begin
                            diff <= sum_sq - z_sq[23:8];
                        end else begin
                            diff <= z_sq[23:8] - sum_sq;
                        end
                    end
                    // Cycle 4: Check tolerance
                    else if (cycle_count == 8'd7) begin
                        if (diff <= 32'd16) begin
                            valid_2 <= 1'b1;
                        end
                    end
                end
                
                PERM_3: begin
                    // Cycle 1: Compute x^2 (reg_b * reg_b)
                    if (cycle_count == 8'd8) begin
                        x_sq <= reg_b * reg_b;
                        y_sq <= reg_c * reg_c;
                    end
                    // Cycle 2: Shift and add
                    else if (cycle_count == 8'd9) begin
                        sum_sq <= (x_sq[23:8] + y_sq[23:8]);
                    end
                    // Cycle 2: Compute z^2 (reg_a * reg_a)
                    else if (cycle_count == 8'd9) begin
                        z_sq <= reg_a * reg_a;
                    end
                    // Cycle 3: Compute difference
                    else if (cycle_count == 8'd10) begin
                        if (sum_sq >= z_sq[23:8]) begin
                            diff <= sum_sq - z_sq[23:8];
                        end else begin
                            diff <= z_sq[23:8] - sum_sq;
                        end
                    end
                    // Cycle 4: Check tolerance
                    else if (cycle_count == 8'd11) begin
                        if (diff <= 32'd16) begin
                            valid_3 <= 1'b1;
                        end
                    end
                end
                
                FINISH: begin
                    result <= valid_1 | valid_2 | valid_3;
                    done <= 1'b1;
                end
                
                default: begin
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule
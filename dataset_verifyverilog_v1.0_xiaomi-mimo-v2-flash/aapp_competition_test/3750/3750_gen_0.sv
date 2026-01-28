module table_tennis_problem (
    input clk,
    input rst_n,
    input start,
    input [31:0] k,
    input [31:0] a,
    input [31:0] b,
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] CHECK_K    = 3'd1;
    localparam [2:0] CALC_SETS  = 3'd2;
    localparam [2:0] CHECK_REM  = 3'd3;
    localparam [2:0] SET_RESULT = 3'd4;
    localparam [2:0] FINISH     = 3'd5;

    reg [2:0] state, next_state;
    reg [31:0] sets_a, sets_b;
    reg [31:0] rem_a, rem_b;
    reg [31:0] temp_result;
    reg impos_flag;
    reg [2:0] cycle_count;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            sets_a <= 32'd0;
            sets_b <= 32'd0;
            rem_a <= 32'd0;
            rem_b <= 32'd0;
            temp_result <= 32'd0;
            impos_flag <= 1'b0;
            cycle_count <= 3'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 3'd0;
                    if (start) begin
                        state <= CHECK_K;
                    end else begin
                        state <= IDLE;
                    end
                end

                CHECK_K: begin
                    // Check if k == 0 (shouldn't happen per spec, but safe)
                    if (k == 32'd0) begin
                        result <= 32'hFFFFFFFF;
                        state <= FINISH;
                    end else begin
                        state <= CALC_SETS;
                    end
                    cycle_count <= cycle_count + 3'd1;
                end

                CALC_SETS: begin
                    // Division: sets_a = a / k, sets_b = b / k
                    // Using combinational division (max 1 cycle for 32-bit)
                    sets_a <= a / k;
                    sets_b <= b / k;
                    rem_a <= a % k;
                    rem_b <= b % k;
                    state <= CHECK_REM;
                    cycle_count <= cycle_count + 3'd1;
                end

                CHECK_REM: begin
                    // Check impossibility conditions
                    // Misha: sets_a == 0 AND rem_a != 0
                    // Vanya: sets_b == 0 AND rem_b != 0
                    if ((sets_a == 32'd0 && rem_a != 32'd0) || 
                        (sets_b == 32'd0 && rem_b != 32'd0)) begin
                        impos_flag <= 1'b1;
                    end else begin
                        impos_flag <= 1'b0;
                    end
                    state <= SET_RESULT;
                    cycle_count <= cycle_count + 3'd1;
                end

                SET_RESULT: begin
                    if (impos_flag) begin
                        result <= 32'hFFFFFFFF;  // -1
                    end else begin
                        // sets_a + sets_b
                        temp_result <= sets_a + sets_b;
                    end
                    state <= FINISH;
                    cycle_count <= cycle_count + 3'd1;
                end

                FINISH: begin
                    done <= 1'b1;
                    if (!impos_flag) begin
                        result <= temp_result;
                    end
                    state <= IDLE;
                    cycle_count <= cycle_count + 3'd1;
                end

                default: begin
                    state <= IDLE;
                    result <= 32'd0;
                    done <= 1'b0;
                    sets_a <= 32'd0;
                    sets_b <= 32'd0;
                    rem_a <= 32'd0;
                    rem_b <= 32'd0;
                    temp_result <= 32'd0;
                    impos_flag <= 1'b0;
                    cycle_count <= 3'd0;
                end
            endcase
        end
    end

endmodule
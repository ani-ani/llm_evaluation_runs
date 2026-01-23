module exam_builder(
    input clk,
    input rst_n,
    input start,
    input signed [7:0] a0, b0,
    input signed [7:0] a1, b1,
    input signed [7:0] a2, b2,
    input signed [7:0] a3, b3,
    input signed [7:0] a4, b4,
    input signed [7:0] a5, b5,
    input signed [7:0] a6, b6,
    input signed [7:0] a7, b7,
    output reg [7:0] res0, res1, res2, res3, res4, res5, res6, res7,
    output reg [2:0] op0, op1, op2, op3, op4, op5, op6, op7,
    output reg done,
    output reg impossible
);

    // State encoding
    localparam IDLE = 3'b000;
    localparam SEL = 3'b001;
    localparam CHECK = 3'b010;
    localparam ASSIGN = 3'b011;
    localparam IMP = 3'b100;
    localparam DN = 3'b101;

    reg [2:0] state, next_state;
    reg [2:0] idx; // Current pair index 0-7
    reg [2:0] op_idx; // Operation index 0-2 (+, -, *)

    // Storage for results to check uniqueness
    reg signed [7:0] stored_res [0:7];
    reg valid_stored [0:7]; // Valid bits for stored results

    // Combinational calculation of all results for current pair
    wire signed [7:0] cur_a, cur_b;
    wire signed [7:0] res_add, res_sub, res_mul;
    wire signed [7:0] cur_calc_res;

    // Input selection based on idx
    assign cur_a = (idx == 0) ? a0 :
                   (idx == 1) ? a1 :
                   (idx == 2) ? a2 :
                   (idx == 3) ? a3 :
                   (idx == 4) ? a4 :
                   (idx == 5) ? a5 :
                   (idx == 6) ? a6 : a7;

    assign cur_b = (idx == 0) ? b0 :
                   (idx == 1) ? b1 :
                   (idx == 2) ? b2 :
                   (idx == 3) ? b3 :
                   (idx == 4) ? b4 :
                   (idx == 5) ? b5 :
                   (idx == 6) ? b6 : b7;

    // Arithmetic operations
    assign res_add = cur_a + cur_b;
    assign res_sub = cur_a - cur_b;
    assign res_mul = cur_a * cur_b;

    // Select result based on op_idx
    assign cur_calc_res = (op_idx == 3'b000) ? res_add :
                          (op_idx == 3'b001) ? res_sub : res_mul;

    // Conflict check: Does cur_calc_res exist in stored_res already?
    wire conflict;
    assign conflict = (valid_stored[0] && stored_res[0] == cur_calc_res) ||
                      (valid_stored[1] && stored_res[1] == cur_calc_res) ||
                      (valid_stored[2] && stored_res[2] == cur_calc_res) ||
                      (valid_stored[3] && stored_res[3] == cur_calc_res) ||
                      (valid_stored[4] && stored_res[4] == cur_calc_res) ||
                      (valid_stored[5] && stored_res[5] == cur_calc_res) ||
                      (valid_stored[6] && stored_res[6] == cur_calc_res) ||
                      (valid_stored[7] && stored_res[7] == cur_calc_res);

    // Sequential Logic
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            idx <= 0;
            op_idx <= 0;
            done <= 0;
            impossible <= 0;
            // Reset stored results
            for (i = 0; i < 8; i = i + 1) begin
                valid_stored[i] <= 0;
                stored_res[i] <= 8'sb0;
            end
            // Reset outputs
            res0 <= 0; res1 <= 0; res2 <= 0; res3 <= 0;
            res4 <= 0; res5 <= 0; res6 <= 0; res7 <= 0;
            op0 <= 0; op1 <= 0; op2 <= 0; op3 <= 0;
            op4 <= 0; op5 <= 0; op6 <= 0; op7 <= 0;
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    if (start) begin
                        idx <= 0;
                        op_idx <= 0;
                        done <= 0;
                        impossible <= 0;
                        // Clear valid bits on start, but keep stored values (they get overwritten anyway)
                        for (i = 0; i < 8; i = i + 1) valid_stored[i] <= 0;
                    end
                end

                SEL: begin
                    // Just maintains idx and op_idx
                end

                CHECK: begin
                    // Logic handled in next_state logic mostly, but we can increment op_idx here if needed
                    // Actually, let's handle op increment in state transition logic or in this block
                    if (conflict && op_idx < 3'b010) begin
                        op_idx <= op_idx + 1;
                    end
                end

                ASSIGN: begin
                    // Store result and operator for current pair
                    valid_stored[idx] <= 1;
                    stored_res[idx] <= cur_calc_res;

                    // Assign specific output based on idx
                    case(idx)
                        3'd0: begin res0 <= cur_calc_res; op0 <= op_idx; end
                        3'd1: begin res1 <= cur_calc_res; op1 <= op_idx; end
                        3'd2: begin res2 <= cur_calc_res; op2 <= op_idx; end
                        3'd3: begin res3 <= cur_calc_res; op3 <= op_idx; end
                        3'd4: begin res4 <= cur_calc_res; op4 <= op_idx; end
                        3'd5: begin res5 <= cur_calc_res; op5 <= op_idx; end
                        3'd6: begin res6 <= cur_calc_res; op6 <= op_idx; end
                        3'd7: begin res7 <= cur_calc_res; op7 <= op_idx; end
                    endcase

                    // Move to next pair
                    if (idx < 3'd7) begin
                        idx <= idx + 1;
                        op_idx <= 0; // Reset op for next pair
                    end
                end

                IMP: begin
                    impossible <= 1;
                end

                DN: begin
                    done <= 1;
                end
            endcase
        end
    end

    // Next State Logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) next_state = SEL;
                else next_state = IDLE;
            end

            SEL: begin
                // Start checking operations for current pair
                next_state = CHECK;
            end

            CHECK: begin
                if (!conflict) begin
                    // Valid unique result found
                    next_state = ASSIGN;
                end else begin
                    // Conflict, try next operation
                    if (op_idx == 3'b010) begin // Tried all 3 (+, -, *), 000, 001, 010
                        next_state = IMP;
                    end else begin
                        next_state = CHECK; // Wait for op_idx increment (handled in sequential)
                    end
                end
            end

            ASSIGN: begin
                if (idx == 3'd7) next_state = DN;
                else next_state = SEL;
            end

            IMP: next_state = IMP;
            DN: next_state = DN;

            default: next_state = IDLE;
        endcase
    end

endmodule
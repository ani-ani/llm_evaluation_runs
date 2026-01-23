module exam_builder (
    input clk,
    input rst_n,
    input start,
    input [7:0] a0, b0,
    input [7:0] a1, b1,
    input [7:0] a2, b2,
    input [7:0] a3, b3,
    input [7:0] a4, b4,
    input [7:0] a5, b5,
    input [7:0] a6, b6,
    input [7:0] a7, b7,
    output reg [7:0] res0, res1, res2, res3, res4, res5, res6, res7,
    output reg [2:0] op0, op1, op2, op3, op4, op5, op6, op7,
    output reg done,
    output reg impossible
);

    // State definitions
    typedef enum logic [1:0] {
        IDLE,
        SELECTION,
        IMPOSSIBLE,
        DONE
    } state_t;

    state_t current_state, next_state;

    // Registers for storing results and operations
    reg [7:0] results [0:7];
    reg [2:0] operations [0:7];

    // Register to track used results
    reg [7:0] used_results [0:7];
    reg [2:0] current_pair;
    reg [2:0] op_attempt;
    reg [7:0] temp_result;
    reg result_found;
    reg [7:0] temp_used [0:7];

    // Combinational block to compute all possible results
    wire signed [7:0] add0 = $signed(a0) + $signed(b0);
    wire signed [7:0] sub0 = $signed(a0) - $signed(b0);
    wire signed [7:0] mul0 = $signed(a0) * $signed(b0);
    wire signed [7:0] add1 = $signed(a1) + $signed(b1);
    wire signed [7:0] sub1 = $signed(a1) - $signed(b1);
    wire signed [7:0] mul1 = $signed(a1) * $signed(b1);
    wire signed [7:0] add2 = $signed(a2) + $signed(b2);
    wire signed [7:0] sub2 = $signed(a2) - $signed(b2);
    wire signed [7:0] mul2 = $signed(a2) * $signed(b2);
    wire signed [7:0] add3 = $signed(a3) + $signed(b3);
    wire signed [7:0] sub3 = $signed(a3) - $signed(b3);
    wire signed [7:0] mul3 = $signed(a3) * $signed(b3);
    wire signed [7:0] add4 = $signed(a4) + $signed(b4);
    wire signed [7:0] sub4 = $signed(a4) - $signed(b4);
    wire signed [7:0] mul4 = $signed(a4) * $signed(b4);
    wire signed [7:0] add5 = $signed(a5) + $signed(b5);
    wire signed [7:0] sub5 = $signed(a5) - $signed(b5);
    wire signed [7:0] mul5 = $signed(a5) * $signed(b5);
    wire signed [7:0] add6 = $signed(a6) + $signed(b6);
    wire signed [7:0] sub6 = $signed(a6) - $signed(b6);
    wire signed [7:0] mul6 = $signed(a6) * $signed(b6);
    wire signed [7:0] add7 = $signed(a7) + $signed(b7);
    wire signed [7:0] sub7 = $signed(a7) - $signed(b7);
    wire signed [7:0] mul7 = $signed(a7) * $signed(b7);

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            done <= 0;
            impossible <= 0;
            current_pair <= 0;
            op_attempt <= 0;
            result_found <= 0;
            for (int i = 0; i < 8; i = i + 1) begin
                results[i] <= 0;
                operations[i] <= 0;
                used_results[i] <= 0;
            end
        end else begin
            current_state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) begin
                    next_state = SELECTION;
                end
            end
            SELECTION: begin
                if (result_found) begin
                    if (current_pair == 7) begin
                        next_state = DONE;
                    end else begin
                        next_state = SELECTION;
                    end
                end else if (op_attempt == 2) begin
                    next_state = IMPOSSIBLE;
                end else begin
                    next_state = SELECTION;
                end
            end
            IMPOSSIBLE: begin
                next_state = IDLE;
            end
            DONE: begin
                next_state = IDLE;
            end
        endcase
    end

    // Selection logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset handled in state machine
        end else if (current_state == SELECTION) begin
            case (current_pair)
                0: begin
                    case (op_attempt)
                        0: temp_result = add0;
                        1: temp_result = sub0;
                        2: temp_result = mul0;
                    endcase
                end
                1: begin
                    case (op_attempt)
                        0: temp_result = add1;
                        1: temp_result = sub1;
                        2: temp_result = mul1;
                    endcase
                end
                2: begin
                    case (op_attempt)
                        0: temp_result = add2;
                        1: temp_result = sub2;
                        2: temp_result = mul2;
                    endcase
                end
                3: begin
                    case (op_attempt)
                        0: temp_result = add3;
                        1: temp_result = sub3;
                        2: temp_result = mul3;
                    endcase
                end
                4: begin
                    case (op_attempt)
                        0: temp_result = add4;
                        1: temp_result = sub4;
                        2: temp_result = mul4;
                    endcase
                end
                5: begin
                    case (op_attempt)
                        0: temp_result = add5;
                        1: temp_result = sub5;
                        2: temp_result = mul5;
                    endcase
                end
                6: begin
                    case (op_attempt)
                        0: temp_result = add6;
                        1: temp_result = sub6;
                        2: temp_result = mul6;
                    endcase
                end
                7: begin
                    case (op_attempt)
                        0: temp_result = add7;
                        1: temp_result = sub7;
                        2: temp_result = mul7;
                    endcase
                end
            endcase

            // Check if result is unique
            result_found = 1;
            for (int i = 0; i < 8; i = i + 1) begin
                if (used_results[i] == temp_result) begin
                    result_found = 0;
                end
            end

            if (result_found) begin
                results[current_pair] = temp_result;
                operations[current_pair] = op_attempt;
                used_results[current_pair] = temp_result;
                if (current_pair == 7) begin
                    done = 1;
                end else begin
                    current_pair = current_pair + 1;
                    op_attempt = 0;
                end
            end else if (op_attempt == 2) begin
                impossible = 1;
            end else begin
                op_attempt = op_attempt + 1;
            end
        end
    end

    // Output assignments
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            res0 <= 0; res1 <= 0; res2 <= 0; res3 <= 0;
            res4 <= 0; res5 <= 0; res6 <= 0; res7 <= 0;
            op0 <= 0; op1 <= 0; op2 <= 0; op3 <= 0;
            op4 <= 0; op5 <= 0; op6 <= 0; op7 <= 0;
        end else begin
            res0 <= results[0];
            res1 <= results[1];
            res2 <= results[2];
            res3 <= results[3];
            res4 <= results[4];
            res5 <= results[5];
            res6 <= results[6];
            res7 <= results[7];
            op0 <= operations[0];
            op1 <= operations[1];
            op2 <= operations[2];
            op3 <= operations[3];
            op4 <= operations[4];
            op5 <= operations[5];
            op6 <= operations[6];
            op7 <= operations[7];
        end
    end

endmodule
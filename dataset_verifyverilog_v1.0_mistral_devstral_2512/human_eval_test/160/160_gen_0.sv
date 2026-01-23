module algebra_eval(
    input clk,
    input rst_n,
    input start,
    input [2:0] num_operators,
    input [7:0][2:0] operator,
    input [7:0][31:0] operand,
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] CHECK_PRECEDENCE = 2'd1;
    localparam [1:0] CALCULATE = 2'd2;
    localparam [1:0] DONE_STATE = 2'd3;

    reg [1:0] state;
    reg [3:0] op_index;
    reg [3:0] pass;
    reg [31:0] temp_operand [0:8];
    reg [2:0] temp_operator [0:7];
    reg [3:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 4'd50;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            op_index <= 4'd0;
            pass <= 4'd0;
            result <= 32'd0;
            done <= 1'b0;
            cycle_count <= 4'd0;
            integer i;
            for (i = 0; i < 9; i = i + 1) begin
                temp_operand[i] <= 32'd0;
            end
            for (i = 0; i < 8; i = i + 1) begin
                temp_operator[i] <= 3'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 4'd0;
                    if (start) begin
                        state <= CHECK_PRECEDENCE;
                        op_index <= 4'd0;
                        pass <= 4'd0;
                        integer i;
                        for (i = 0; i < 9; i = i + 1) begin
                            temp_operand[i] <= operand[i];
                        end
                        for (i = 0; i < 8; i = i + 1) begin
                            temp_operator[i] <= operator[i];
                        end
                    end
                end

                CHECK_PRECEDENCE: begin
                    cycle_count <= cycle_count + 4'd1;
                    if (pass == 4'd0) begin
                        if (op_index < num_operators) begin
                            if (temp_operator[op_index] == 3'd2 || temp_operator[op_index] == 3'd3 || temp_operator[op_index] == 3'd4) begin
                                state <= CALCULATE;
                            end else begin
                                op_index <= op_index + 4'd1;
                            end
                        end else begin
                            pass <= 4'd1;
                            op_index <= 4'd0;
                        end
                    end else begin
                        if (op_index < num_operators) begin
                            if (temp_operator[op_index] == 3'd0 || temp_operator[op_index] == 3'd1) begin
                                state <= CALCULATE;
                            end else begin
                                op_index <= op_index + 4'd1;
                            end
                        end else begin
                            state <= DONE_STATE;
                        end
                    end
                end

                CALCULATE: begin
                    cycle_count <= cycle_count + 4'd1;
                    reg [31:0] op1, op2;
                    reg [31:0] calc_result;
                    op1 <= temp_operand[op_index];
                    op2 <= temp_operand[op_index + 4'd1];

                    case (temp_operator[op_index])
                        3'd0: calc_result <= op1 + op2;
                        3'd1: calc_result <= op1 - op2;
                        3'd2: begin
                            reg [63:0] mult_temp;
                            mult_temp <= $signed(op1) * $signed(op2);
                            calc_result <= mult_temp[47:16];
                        end
                        3'd3: begin
                            reg [63:0] div_temp;
                            div_temp <= {op1, 16'd0};
                            calc_result <= div_temp / op2;
                        end
                        3'd4: begin
                            reg [31:0] base, exp;
                            reg [31:0] exp_result;
                            base <= op1[31:16];
                            exp <= op2[31:16];
                            if (exp > 16'd16) begin
                                exp <= 16'd16;
                            end
                            exp_result <= 32'd1;
                            integer i;
                            for (i = 0; i < exp; i = i + 1) begin
                                exp_result <= exp_result * base;
                            end
                            calc_result <= {exp_result[31:16], 16'd0};
                        end
                        default: calc_result <= 32'd0;
                    endcase

                    temp_operand[op_index] <= calc_result;
                    integer i;
                    for (i = op_index + 4'd1; i < 8; i = i + 1) begin
                        temp_operand[i] <= temp_operand[i + 4'd1];
                    end
                    for (i = op_index; i < 7; i = i + 1) begin
                        temp_operator[i] <= temp_operator[i + 4'd1];
                    end
                    state <= CHECK_PRECEDENCE;
                end

                DONE_STATE: begin
                    result <= temp_operand[0];
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule
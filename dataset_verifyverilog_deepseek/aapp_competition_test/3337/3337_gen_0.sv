module stack_operations (
    input clk,
    input rst_n,
    input cmd_valid,
    input [1:0] op_type,
    input [3:0] v,
    input [3:0] w,
    output logic [4:0] result,
    output logic result_valid,
    output logic done
);

    parameter NUM_STACKS = 16;
    parameter STACK_DEPTH = 16;

    logic [3:0] stacks [0:NUM_STACKS-1][0:STACK_DEPTH-1];
    logic [4:0] top [0:NUM_STACKS-1];
    logic [3:0] current_step;
    logic [3:0] next_stack [0:STACK_DEPTH-1];
    logic [4:0] next_top;
    logic [3:0] next_popped_value;
    logic [4:0] next_common_count;

    always_comb begin
        next_top = top[v];
        for (int i = 0; i < STACK_DEPTH; i++) begin
            next_stack[i] = stacks[v][i];
        end
        next_popped_value = 0;
        next_common_count = 0;

        if (cmd_valid && current_step < 15) begin
            unique case (op_type)
                2'b00: begin
                    if (next_top < STACK_DEPTH) begin
                        next_stack[next_top] = current_step;
                        next_top = next_top + 1;
                    end
                end
                2'b01: begin
                    if (next_top > 0) begin
                        next_popped_value = next_stack[next_top-1];
                        next_top = next_top - 1;
                    end
                end
                2'b10: begin
                    logic [15:0] pres_i = 0, pres_w = 0;
                    for (int j = 0; j < next_top; j++) begin
                        pres_i[next_stack[j]] = 1'b1;
                    end
                    for (int j = 0; j < top[w]; j++) begin
                        pres_w[stacks[w][j]] = 1'b1;
                    end
                    next_common_count = $countones(pres_i & pres_w);
                end
                default: ;
            endcase
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_step <= 0;
            done <= 0;
            result <= 0;
            result_valid <= 0;
            for (int s = 0; s < NUM_STACKS; s++) begin
                top[s] <= 0;
                for (int e = 0; e < STACK_DEPTH; e++) begin
                    stacks[s][e] <= 0;
                end
            end
        end else begin
            result_valid <= 0;
            if (cmd_valid && !done) begin
                if (current_step < 15) begin
                    current_step <= current_step + 1;
                    int dest = current_step + 1;
                    top[dest] <= next_top;
                    for (int e = 0; e < STACK_DEPTH; e++) begin
                        stacks[dest][e] <= next_stack[e];
                    end
                end

                if (op_type == 2'b01 || op_type == 2'b10) begin
                    result_valid <= 1;
                    if (op_type == 2'b01) begin
                        result <= {1'b0, next_popped_value};
                    end else begin
                        result <= next_common_count;
                    end
                end
                if (current_step == 14) done <= 1;
            end
        end
    end

endmodule
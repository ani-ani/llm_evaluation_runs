module stack_game (input clk, input rst_n, input start, input [2:0] op_code, input [3:0] v, input [3:0] w, input [7:0] data_in, output reg [7:0] result, output reg result_valid, output reg [3:0] debug_stack_count);

reg [3:0] current_step;
reg [2:0] op_code_reg;
reg [3:0] v_reg;
reg [3:0] w_reg;
reg [7:0] data_in_reg;
reg [3:0] depths [0:15];
reg [7:0] stacks [0:15][0:15];
reg [15:0] valid_stacks;
reg [15:0] intersection_count;
reg [3:0] intersect_counter;
reg [3:0] state;

always_ff @(posedge clk) begin
    if (!rst_n) begin
        current_step <= 1;
        op_code_reg <= 3'd0;
        v_reg <= 4'd0;
        w_reg <= 4'd0;
        data_in_reg <= 8'd0;
        depths <= 16'd0;
        valid_stacks <= 16'd0;
        stacks <= 16'h0;
        intersection_count <= 16'd0;
        intersect_counter <= 4'd0;
        state <= 3'd0;
    end else begin
        case (state)
            3'd0: begin // IDLE
                if (start) begin
                    if (op_code != 3'd0) begin
                        op_code_reg <= op_code;
                        v_reg <= v;
                        w_reg <= w;
                        data_in_reg <= data_in;
                        state <= 3'd1;
                    end
                end
            end
            3'd1: begin // PROCESSING
                depths[current_step] <= depths[v_reg];
                if (depths[v_reg] > 0) stacks[current_step][0] <= stacks[v_reg][0]; else stacks[current_step][0] <= 8'd0;
                if (depths[v_reg] > 1) stacks[current_step][1] <= stacks[v_reg][1]; else stacks[current_step][1] <= 8'd0;
                if (depths[v_reg] > 2) stacks[current_step][2] <= stacks[v_reg][2]; else stacks[current_step][2] <= 8'd0;
                if (depths[v_reg] > 3) stacks[current_step][3] <= stacks[v_reg][3]; else stacks[current_step][3] <= 8'd0;
                if (depths[v_reg] > 4) stacks[current_step][4] <= stacks[v_reg][4]; else stacks[current_step][4] <= 8'd0;
                if (depths[v_reg] > 5) stacks[current_step][5] <= stacks[v_reg][5]; else stacks[current_step][5] <= 8'd0;
                if (depths[v_reg] > 6) stacks[current_step][6] <= stacks[v_reg][6]; else stacks[current_step][6] <= 8'd0;
                if (depths[v_reg] > 7) stacks[current_step][7] <= stacks[v_reg][7]; else stacks[current_step][7] <= 8'd0;
                if (depths[v_reg] > 8) stacks[current_step][8] <= stacks[v_reg][8]; else stacks[current_step][8] <= 8'd0;
                if (depths[v_reg] > 9) stacks[current_step][9] <= stacks[v_reg][9]; else stacks[current_step][9] <= 8'd0;
                if (depths[v_reg] > 10) stacks[current_step][10] <= stacks[v_reg][10]; else stacks[current_step][10] <= 8'd0;
                if (depths[v_reg] > 11) stacks[current_step][11] <= stacks[v_reg][11]; else stacks[current_step][11] <= 8'd0;
                if (depths[v_reg] > 12) stacks[current_step][12] <= stacks[v_reg][12]; else stacks[current_step][12] <= 8'd0;
                if (depths[v_reg] > 13) stacks[current_step][13] <= stacks[v_reg][13]; else stacks[current_step][13] <= 8'd0;
                if (depths[v_reg] > 14) stacks[current_step][14] <= stacks[v_reg][14]; else stacks[current_step][14] <= 8'd0;
                if (depths[v_reg] > 15) stacks[current_step][15] <= stacks[v_reg][15]; else stacks[current_step][15] <= 8'd0;

                if (op_code_reg == 1) begin // push
                    if (depths[current_step] < 16) begin
                        stacks[current_step][depths[current_step]] <= data_in_reg;
                        depths[current_step] <= depths[current_step] + 1;
                    end
                end else if (op_code_reg == 2) begin // pop
                    if (depths[current_step] > 0) begin
                        result <= stacks[current_step][depths[current_step]-1];
                    end
                    depths[current_step] <= depths[current_step] - 1;
                end else if (op_code_reg == 3) begin // intersect
                    state <= 3'd2;
                    intersect_counter <= 4'd0;
                    intersection_count <= 16'd0;
                end
                state <= 3'd3;
            end
            3'd2: begin // COUNTING_INTERSECT
                intersect_counter <= intersect_counter + 1;
                if (intersect_counter < 16) begin
                    if (intersect_counter < depths[current_step]) begin
                        intersection_count <= intersection_count + 1;
                    end
                end
                if (intersect_counter == 16) begin
                    state <= 3'd3;
                end
            end
            3'd3: begin // DONE
                if (op_code_reg == 1 || op_code_reg == 2) begin
                    valid_stacks[current_step] <= 1;
                end
                current_step <= (current_step + 1) % 16;
                state <= 3'd0;
                if (op_code_reg == 2) begin
                    result_valid <= 1;
                end else if (op_code_reg == 3) begin
                    result_valid <= 1;
                    result <= intersection_count;
                end
            end
        endcase
    end
end

assign debug_stack_count = 
    (valid_stacks[0]?1:0) + (valid_stacks[1]?1:0) + (valid_stacks[2]?1:0) + (valid_stacks[3]?1:0) +
    (valid_stacks[4]?1:0) + (valid_stacks[5]?1:0) + (valid_stacks[6]?1:0) + (valid_stacks[7]?1:0) +
    (valid_stacks[8]?1:0) + (valid_stacks[9]?1:0) + (valid_stacks[10]?1:0) + (valid_stacks[11]?1:0) +
    (valid_stacks[12]?1:0) + (valid_stacks[13]?1:0) + (valid_stacks[14]?1:0) + (valid_stacks[15]?1:0);

endmodule
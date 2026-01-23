module gold_stores (
    input clk,
    input rst_n,
    input start,
    input [7:0] valid_count,
    input [7:0][15:0] time_array,
    input [7:0][15:0] altitude_array,
    output reg [3:0] result,
    output reg done
);

reg [2:0] order [7:0];
reg [3:0] result_reg;
reg done_reg;
reg [2:0] state;
reg [2:0] sort_counter;
reg [15:0] cumulative_time;
reg [3:0] count;
reg [2:0] process_i;
reg [2:0] process_counter;
reg [2:0] current_index;

// Initialize order based on valid_count
assign order[0] = valid_count > 0 ? 0 : 0;
assign order[1] = valid_count > 1 ? 1 : 0;
assign order[2] = valid_count > 2 ? 2 : 0;
assign order[3] = valid_count > 3 ? 3 : 0;
assign order[4] = valid_count > 4 ? 4 : 0;
assign order[5] = valid_count > 5 ? 5 : 0;
assign order[6] = valid_count > 6 ? 6 : 0;
assign order[7] = valid_count > 7 ? 7 : 0;

// Default assignments
assign result_reg = 4'd0;
assign done_reg = 1'b0;
assign state = 3'd0;
assign sort_counter = 3'd0;
assign cumulative_time = 16'd0;
assign count = 4'd0;
assign process_i = 3'd0;
assign process_counter = 3'd0;
assign current_index = 3'd0;

always @(posedge clk) begin
    if (!rst_n) begin
        order <= 0;
        result_reg <= 4'd0;
        done_reg <= 1'b0;
        state <= 3'd0;
        sort_counter <= 3'd0;
        cumulative_time <= 16'd0;
        count <= 4'd0;
        process_i <= 3'd0;
        process_counter <= 3'd0;
        current_index <= 3'd0;
    end else begin
        if (start) begin
            if (state == 3'd0) begin
                state <= 3'd1;
                sort_counter <= 3'd8;
            end
        end
        case (state)
            3'd0: // IDLE
                done_reg <= 1'b0;
                result_reg <= 4'd0;
                if (start) begin
                    state <= 3'd1;
                    sort_counter <= 3'd8;
                end
            end
            3'd1: // SORT_PHASE
                if (sort_counter == 0) begin
                    state <= 3'd2;
                    process_counter <= valid_count;
                    process_i <= 3'd0;
                    cumulative_time <= 16'd0;
                    count <= 4'd0;
                end else begin
                    sort_counter <= sort_counter - 1;
                end
                done_reg <= 1'b0;
                result_reg <= 4'd0;
            end
            3'd2: // PROCESS_PHASE
                if (process_counter < valid_count) begin
                    // Determine current_index based on process_i
                    if (process_i == 0) current_index = order[0];
                    else if (process_i == 1) current_index = order[1];
                    else if (process_i == 2) current_index = order[2];
                    else if (process_i == 3) current_index = order[3];
                    else if (process_i == 4) current_index = order[4];
                    else if (process_i == 5) current_index = order[5];
                    else if (process_i == 6) current_index = order[6];
                    else if (process_i == 7) current_index = order[7];
                    else current_index = 8'd0;

                    if (cumulative_time + time_array[current_index] <= altitude_array[current_index]) begin
                        cumulative_time <= cumulative_time + time_array[current_index];
                        count <= count + 1;
                    end
                    process_i <= process_i + 1;
                    process_counter <= process_counter + 1;
                end else begin
                    state <= 3'd3;
                    result_reg <= count;
                end
                done_reg <= 1'b0;
            end
            3'd3: // DONE
                done_reg <= 1'b1;
                result_reg <= count;
            end
        endcase
    end
end

// Output assignments
assign result = result_reg;
assign done = done_reg;

endmodule
module min_k_records(input clk, input rst_n, input start, input [3:0] K, input [31:0] name_0, name_1, name_2, name_3, input [7:0] score_0, score_1, score_2, score_3, output reg [31:0] out_name_0, out_name_1, out_name_2, out_name_3, output reg [7:0] out_score_0, out_score_1, out_score_2, out_score_3, output reg done);
// Internal signals
reg [31:0] current_names [4];
reg [7:0] current_scores [4];
reg [3:0] desired_K;
reg [1:0] state; // 0:IDLE, 1:SORT, 2:OUTPUT, 3:DONE
reg [1:0] sort_counter;
reg [2:0] out_counter;

// Output assignments
always @(posedge clk) begin
    if (state == 2) begin // OUTPUT state
        if (desired_K > 0) begin
            out_name_0 = current_names[0];
            out_score_0 = current_scores[0];
        end else begin
            out_name_0 = 32'd0;
            out_score_0 = 8'd0;
        end
        if (desired_K > 1) begin
            out_name_1 = current_names[1];
            out_score_1 = current_scores[1];
        end else begin
            out_name_1 = 32'd0;
            out_score_1 = 8'd0;
        end
        if (desired_K > 2) begin
            out_name_2 = current_names[2];
            out_score_2 = current_scores[2];
        end else begin
            out_name_2 = 32'd0;
            out_score_2 = 8'd0;
        end
        if (desired_K > 3) begin
            out_name_3 = current_names[3];
            out_score_3 = current_scores[3];
        end else begin
            out_name_3 = 32'd0;
            out_score_3 = 8'd0;
        end
    end
end

// State machine and control logic
always @(posedge clk) begin
    if (!rst_n) begin
        state <= 2'd0;
        sort_counter <= 2'd0;
        out_counter <= 3'd0;
        desired_K <= 4'd0;
        current_names <= 32'd0;
        current_scores <= 8'd0;
        done <= 1'b0;
    end else begin
        if (state == 2'd0) begin // IDLE
            if (start) begin
                current_names <= {name_0, name_1, name_2, name_3};
                current_scores <= {score_0, score_1, score_2, score_3};
                desired_K <= K;
                state <= 2'd1;
                sort_counter <= 2'd2;
            end
        end else if (state == 2'd1) begin // SORT state
            if (sort_counter == 2'd2) begin // Stage 1
                reg [31:0] temp_names [4];
                reg [7:0] temp_scores [4];
                temp_names[0] = current_names[0];
                temp_names[1] = current_names[1];
                temp_names[2] = current_names[2];
                temp_names[3] = current_names[3];
                temp_scores[0] = current_scores[0];
                temp_scores[1] = current_scores[1];
                temp_scores[2] = current_scores[2];
                temp_scores[3] = current_scores[3];
                if (temp_scores[0] > temp_scores[1]) begin
                    {temp_names[0], temp_names[1]} = {temp_names[1], temp_names[0]};
                    {temp_scores[0], temp_scores[1]} = {temp_scores[1], temp_scores[0]};
                end
                if (temp_scores[2] > temp_scores[3]) begin
                    {temp_names[2], temp_names[3]} = {temp_names[3], temp_names[2]};
                    {temp_scores[2], temp_scores[3]} = {temp_scores[3], temp_scores[2]};
                end
                current_names <= temp_names;
                current_scores <= temp_scores;
                sort_counter <= 2'd1;
            end else if (sort_counter == 2'd1) begin // Stage 2
                temp_names = current_names;
                temp_scores = current_scores;
                if (temp_scores[0] > temp_scores[2]) begin
                    {temp_names[0], temp_names[2]} = {temp_names[2], temp_names[0]};
                    {temp_scores[0], temp_scores[2]} = {temp_scores[2], temp_scores[0]};
                end
                if (temp_scores[1] > temp_scores[3]) begin
                    {temp_names[1], temp_names[3]} = {temp_names[3], temp_names[1]};
                    {temp_scores[1], temp_scores[3]} = {temp_scores[3], temp_scores[1]};
                end
                current_names <= temp_names;
                current_scores <= temp_scores;
                sort_counter <= 2'd0;
            end else if (sort_counter == 2'd0) begin // Stage 3
                temp_names = current_names;
                temp_scores = current_scores;
                if (temp_scores[1] > temp_scores[2]) begin
                    {temp_names[1], temp_names[2]} = {temp_names[2], temp_names[1]};
                    {temp_scores[1], temp_scores[2]} = {temp_scores[2], temp_scores[1]};
                end
                current_names <= temp_names;
                current_scores <= temp_scores;
                // Move to OUTPUT state and initialize out_counter
                state <= 2'd2;
                out_counter <= 3'd3;
                sort_counter <= 2'd0; // keep at 0
            end
            // Transition to OUTPUT if stage is done
            if (sort_counter == 2'd0) begin
                // Handled above by setting state to 2
            end
        end else if (state == 2'd2) begin // OUTPUT state
            out_counter <= out_counter - 1;
            if (out_counter == 3'd0) begin
                state <= 2'd3;
            end
        end else if (state == 2'd3) begin // DONE
            done <= 1'b1;
        end
    end
end
endmodule
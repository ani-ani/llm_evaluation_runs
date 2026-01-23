module heap_subset (
    input clk,
    input rst_n,
    input start,
    // Parents (not used)
    input [2:0] parent_0, parent_1, parent_2, parent_3,
    input [2:0] parent_4, parent_5, parent_6, parent_7,
    // Values
    input [15:0] value_0, value_1, value_2, value_3,
    input [15:0] value_4, value_5, value_6, value_7,
    output reg [3:0] result,
    output reg done);

reg [15:0] sampled_value [0:7];
reg [3:0] max_count;
reg [2:0] state; // 0:IDLE, 1:BUILD, 2:DONE
reg [3:0] threshold_idx;
reg [3:0] node_idx;
reg [1:0] sub_state; // 00: threshold loop, 01: node loop
reg [3:0] count;
reg [3:0] result_reg;
reg done_reg;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <=0;
        sampled_value <= 16'b0;
        max_count <=4'b0;
        threshold_idx <=4'b0;
        node_idx <=4'b0;
        sub_state <=2'b00;
        count <=4'b0;
        result_reg <=4'b0;
        done_reg <=0;
    end else begin
        if (state ==0) begin // IDLE
            if (start) begin
                sampled_value <= {value_0, value_1, value_2, value_3, value_4, value_5, value_6, value_7};
                state <=1;
                threshold_idx <=4'b0;
                sub_state <=2'b00;
            end
            result_reg <=4'b0;
            done_reg <=0;
        end else if (state ==1) begin // BUILD
            if (sub_state ==2'b00) begin // threshold loop
                if (threshold_idx ==8) begin
                    // All thresholds processed
                    state <=2;
                    result_reg <= max_count;
                    done_reg <=1;
                end else begin
                    // Move to node loop
                    sub_state <=2'b01;
                    node_idx <=4'b0;
                    count <=4'b0;
                end
            end else if (sub_state ==2'b01) begin // node loop
                if (node_idx ==8) begin
                    // Update max_count
                    if (count > max_count) max_count <= count;
                    // Move back to threshold loop
                    sub_state <=2'b00;
                    threshold_idx <= threshold_idx +1;
                end else begin
                    // Check current node
                    if (sampled_value[node_idx] > sampled_value[threshold_idx]) begin
                        count <= count +1;
                    end
                    node_idx <= node_idx +1;
                end
            end
            // done is 0 while building
            done_reg <=0;
            result_reg <=4'b0; // or keep previous? But in DONE it's set
        end else begin // DONE
            done_reg <=1;
            result_reg <= max_count;
        end
    end
end

// Outputs
assign result = result_reg;
assign done = done_reg;

endmodule
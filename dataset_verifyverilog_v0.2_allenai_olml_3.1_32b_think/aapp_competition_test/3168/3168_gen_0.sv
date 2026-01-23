module bst_insertion(output reg [7:0] cumulative_depth, output reg done, input clk, input rst_n, input [7:0] data_in, input start);

reg [7:0] node_val [0:7] = 8'b0;
reg [7:0] left_child [0:7] = 8'hFF;
reg [7:0] right_child [0:7] = 8'hFF;
reg [2:0] state = 3'b000; // IDLE=0, LOAD_ROOT=1, SEARCH_INSERT=2, UPDATE_DEPTH=3, DONE=4
reg [3:0] insertion_count = 4'd0;
reg [7:0] cumulative_depth = 8'b0;
reg done = 1'b0;
reg [7:0] insert_data;
reg [2:0] current_node_index = 2'd0;
reg [3:0] current_depth = 4'd0;
reg [3:0] cycle_count = 4'd0;

always @(posedge clk) begin
    if (!rst_n) begin
        node_val <= 8'b0;
        left_child <= 8'hFF;
        right_child <= 8'hFF;
        state <= 3'b000;
        insertion_count <= 4'd0;
        cumulative_depth <= 8'b0;
        done <= 1'b0;
        insert_data <= 8'b0;
        current_node_index <= 2'd0;
        current_depth <= 4'd0;
        cycle_count <= 4'd0;
    end else begin
        if (state == 3'b000) begin // IDLE
            if (start) begin
                insert_data <= data_in;
                if (insertion_count < 8) begin
                    if (insertion_count == 4'd0) begin
                        state <= 3'b001; // LOAD_ROOT
                    end else begin
                        state <= 3'b010; // SEARCH_INSERT
                        current_node_index <= 2'd0;
                        current_depth <= 4'd0;
                    end
                end
            end
        end else if (state == 3'b001) begin // LOAD_ROOT
            node_val[0] <= insert_data;
            left_child[0] <= 8'hFF;
            right_child[0] <= 8'hFF;
            insertion_count <= insertion_count + 1;
            cumulative_depth <= cumulative_depth + 0;
            if (insertion_count == 1) begin
                state <= 3'b011; // UPDATE_DEPTH
            end
        end else if (state == 3'b011) begin // UPDATE_DEPTH
            cycle_count <= cycle_count + 1;
            if (cycle_count == 10) begin
                done <= 1'b1;
                state <= 3'b100; // DONE
            end
        end else if (state == 3'b100) begin // DONE
            // stay in DONE
        end
    end
endmodule
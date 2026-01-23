module min_scc_finder (input clk, input rst_n, input start, input edge_valid, input [3:0] src_node, input [3:0] dst_node, output reg [3:0] result_size, output reg [3:0] result_nodes [10], output reg done);
reg [3:0] original_adj [10][20] = 0;
reg [3:0] transposed_adj [10][20] = 0;
reg [4:0] original_count [10] = 0;
reg [4:0] transposed_count [10] = 0;
reg [3:0] finish_time [10] = 0;
reg [3:0] visited [10] = 0;
reg [3:0] stack [10] = 0;
reg [3:0] stack_ptr = 0;
reg [3:0] time_counter = 0;
reg [2:0] state;
reg [3:0] min_candidate;
reg [3:0] candidate_node;
initial begin
    state <= 3'b000;
    min_candidate <= 4'd10;
    candidate_node <= 4'd0;
end
always @(posedge clk) begin
    if (!rst_n) begin
        state <= 3'b000;
        original_count <= 0;
        transposed_count <= 0;
        original_adj <= 0;
        transposed_adj <= 0;
        finish_time <= 0;
        visited <= 0;
        stack <= 0;
        stack_ptr <= 0;
        time_counter <= 0;
        min_candidate <= 4'd10;
        candidate_node <= 4'd0;
        result_size <= 4'd0;
        result_nodes[0] <= 4'd0;
        result_nodes[1] <= 4'd0;
        result_nodes[2] <= 4'd0;
        result_nodes[3] <= 4'd0;
        result_nodes[4] <= 4'd0;
        result_nodes[5] <= 4'd0;
        result_nodes[6] <= 4'd0;
        result_nodes[7] <= 4'd0;
        result_nodes[8] <= 4'd0;
        result_nodes[9] <= 4'd0;
        done <= 0;
    end else begin
        case (state)
            3'b000: begin // IDLE
                if (start)
                    state <= 3'b001; // LOAD
                else
                    state <= 3'b000;
            end
            3'b001: begin // LOAD
                if (edge_valid) begin
                    original_adj[src_node][original_count[src_node]] <= dst_node;
                    original_count[src_node] <= original_count[src_node] + 1;
                    transposed_adj[dst_node][transposed_count[dst_node]] <= src_node;
                    transposed_count[dst_node] <= transposed_count[dst_node] + 1;
                end
                if (!start) begin
                    state <= 3'b010; // COMPUTE
                end
            end
            3'b010: begin // COMPUTE
                min_candidate <= 4'd10;
                candidate_node <= 4'd0;
                if (original_count[0] == 0) begin
                    if (1 < min_candidate) begin
                        min_candidate <= 1;
                        candidate_node <= 0;
                    end
                end
                if (original_count[1] == 0) begin
                    if (1 < min_candidate) begin
                        min_candidate <= 1;
                        candidate_node <= 1;
                    end
                end
                if (original_count[2] == 0) begin
                    if (1 < min_candidate) begin
                        min_candidate <= 1;
                        candidate_node <= 2;
                    end
                end
                if (original_count[3] == 0) begin
                    if (1 < min_candidate) begin
                        min_candidate <= 1;
                        candidate_node <= 3;
                    end
                end
                if (original_count[4] == 0) begin
                    if (1 < min_candidate) begin
                        min_candidate <= 1;
                        candidate_node <= 4;
                    end
                end
                if (original_count[5] == 0) begin
                    if (1 < min_candidate) begin
                        min_candidate <= 1;
                        candidate_node <= 5;
                    end
                end
                if (original_count[6] == 0) begin
                    if (1 < min_candidate) begin
                        min_candidate <= 1;
                        candidate_node <= 6;
                    end
                end
                if (original_count[7] == 0) begin
                    if (1 < min_candidate) begin
                        min_candidate <= 1;
                        candidate_node <= 7;
                    end
                end
                if (original_count[8] == 0) begin
                    if (1 < min_candidate) begin
                        min_candidate <= 1;
                        candidate_node <= 8;
                    end
                end
                if (original_count[9] == 0) begin
                    if (1 < min_candidate) begin
                        min_candidate <= 1;
                        candidate_node <= 9;
                    end
                end
                if (min_candidate == 4'd10) begin
                    min_candidate <= 1;
                    candidate_node <= 0;
                end
                result_size <= min_candidate;
                result_nodes[0] <= candidate_node;
                result_nodes[1] <= 4'd0;
                result_nodes[2] <= 4'd0;
                result_nodes[3] <= 4'd0;
                result_nodes[4] <= 4'd0;
                result_nodes[5] <= 4'd0;
                result_nodes[6] <= 4'd0;
                result_nodes[7] <= 4'd0;
                result_nodes[8] <= 4'd0;
                result_nodes[9] <= 4'd0;
                state <= 3'b011; // DONE_PULSE
            end
            3'b011: begin // DONE_PULSE
                done <= 1;
                state <= 3'b000; // Return to IDLE
            end
        endcase
    end
endmodule
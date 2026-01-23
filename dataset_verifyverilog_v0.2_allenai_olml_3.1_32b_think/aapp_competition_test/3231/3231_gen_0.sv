module friend_groups (input wire clk, input wire rst_n, input wire start, input wire [7:0] n, input wire [3:0] p, input wire [3:0] q, input wire [7:0] src_node, input wire [7:0] dst_node, input wire edge_valid, output reg valid_partition, output reg [7:0] num_groups, output reg [7:0] group_sizes [0:15], output reg done);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        valid_partition <= 0;
        num_groups <= 0;
        done <= 0;
        group_sizes[0] <= 0;
        group_sizes[1] <= 0;
        group_sizes[2] <= 0;
        group_sizes[3] <= 0;
        group_sizes[4] <= 0;
        group_sizes[5] <= 0;
        group_sizes[6] <= 0;
        group_sizes[7] <= 0;
        group_sizes[8] <= 0;
        group_sizes[9] <= 0;
        group_sizes[10] <= 0;
        group_sizes[11] <= 0;
        group_sizes[12] <= 0;
        group_sizes[13] <= 0;
        group_sizes[14] <= 0;
        group_sizes[15] <= 0;
    end else begin
        if (start) 
            done <= 1;
        else 
            done <= 0;
    end
end

endmodule
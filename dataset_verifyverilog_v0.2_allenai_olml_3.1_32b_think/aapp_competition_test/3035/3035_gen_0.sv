module lemonade_trade (
    input clk,
    input rst_n, // active low
    input start,
    input [4:0] num_nodes,
    input [4:0] num_edges, // Not used in this implementation
    input [2:0] pink_idx,
    input [2:0] blue_idx,
    input [15:0] edge_start [15:0], // 16 edges
    input [15:0] edge_end [15:0],
    input [31:0] edge_rate [15:0], // 16 edges
    output reg [31:0] max_blue,
    output reg done
);

    reg [31:0] max_prod [7:0];
    reg [15:0] edge_start_reg [15:0];
    reg [15:0] edge_end_reg [15:0];
    reg [31:0] edge_rate_reg [15:0];
    reg [4:0] num_nodes_reg;
    reg [2:0] pink_idx_reg;
    reg [2:0] blue_idx_reg;
    reg [4:0] num_edges_reg;
    reg [3:0] state; // 4 bits, states: IDLE=0, INIT=1, PROCESSING=2, CAP_CHECK=3, DONE=4
    reg [31:0] new_max_prod [7:0];
    reg updated;
    reg [3:0] iter_cnt;

    localparam IDLE = 4'b0000;
    localparam INIT = 4'b0001;
    localparam PROCESSING = 4'b0010;
    localparam CAP_CHECK = 4'b0011;
    localparam DONE = 4'b0100;

    always @(posedge clk) begin
        if (!rst_n) begin
            state <= IDLE;
            max_prod <= 32'b0;
            edge_start_reg <= 16'b0;
            edge_end_reg <= 16'b0;
            edge_rate_reg <= 32'b0;
            num_nodes_reg <= 4'b0000;
            pink_idx_reg <= 3'b000;
            blue_idx_reg <= 3'b000;
            num_edges_reg <= 4'b0000;
            iter_cnt <= 4'd0;
            done <= 1'b0;
            max_blue <= 32'b0;
        end else begin
            if (state == IDLE) begin
                if (start == 1'b1) begin
                    state <= INIT;
                    num_nodes_reg <= num_nodes;
                    pink_idx_reg <= pink_idx;
                    blue_idx_reg <= blue_idx;
                    num_edges_reg <= num_edges;
                    edge_start_reg <= edge_start;
                    edge_end_reg <= edge_end;
                    edge_rate_reg <= edge_rate;
                end
            end else if (state == INIT) begin
                state <= PROCESSING;
                max_prod <= 32'b0;
                if (pink_idx_reg < 8) 
                    max_prod[pink_idx_reg] <= 32'h00010000; // 1.0
                iter_cnt <= 4'd0;
            end else if (state == PROCESSING) begin
                new_max_prod[0] <= max_prod[0];
                new_max_prod[1] <= max_prod[1];
                new_max_prod[2] <= max_prod[2];
                new_max_prod[3] <= max_prod[3];
                new_max_prod[4] <= max_prod[4];
                new_max_prod[5] <= max_prod[5];
                new_max_prod[6] <= max_prod[6];
                new_max_prod[7] <= max_prod[7];

                // Edge 0
                if (edge_start_reg[0] < num_nodes_reg && edge_end_reg[0] < num_nodes_reg) begin
                    new_max_prod[edge_end_reg[0]] <= 
                        (max_prod[edge_start_reg[0]] * edge_rate_reg[0] >> 16) > new_max_prod[edge_end_reg[0]] ? 
                        (max_prod[edge_start_reg[0]] * edge_rate_reg[0] >> 16) : 
                        new_max_prod[edge_end_reg[0]];
                end

                // Edge 1
                if (edge_start_reg[1] < num_nodes_reg && edge_end_reg[1] < num_nodes_reg) begin
                    new_max_prod[edge_end_reg[1]] <= 
                        (max_prod[edge_start_reg[1]] * edge_rate_reg[1] >> 16) > new_max_prod[edge_end_reg[1]] ? 
                        (max_prod[edge_start_reg[1]] * edge_rate_reg[1] >> 16) : 
                        new_max_prod[edge_end_reg[1]];
                end

                // Edge 2
                if (edge_start_reg[2] < num_nodes_reg && edge_end_reg[2] < num_nodes_reg) begin
                    new_max_prod[edge_end_reg[2]] <= 
                        (max_prod[edge_start_reg[2]] * edge_rate_reg[2] >> 16) > new_max_prod[edge_end_reg[2]] ? 
                        (max_prod[edge_start_reg[2]] * edge_rate_reg[2] >> 16) : 
                        new_max_prod[edge_end_reg[2]];
                end

                // Edge 3
                if (edge_start_reg[3] < num_nodes_reg && edge_end_reg[3] < num_nodes_reg) begin
                    new_max_prod[edge_end_reg[3]] <= 
                        (max_prod[edge_start_reg[3]] * edge_rate_reg[3] >> 16) > new_max_prod[edge_end_reg[3]] ? 
                        (max_prod[edge_start_reg[3]] * edge_rate_reg[3] >> 16) : 
                        new_max_prod[edge_end_reg[3]];
                end

                // Edge 4
                if (edge_start_reg[4] < num_nodes_reg && edge_end_reg[4] < num_nodes_reg) begin
                    new_max_prod[edge_end_reg[4]] <= 
                        (max_prod[edge_start_reg[4]] * edge_rate_reg[4] >> 16) > new_max_prod[edge_end_reg[4]] ? 
                        (max_prod[edge_start_reg[4]] * edge_rate_reg[4] >> 16) : 
                        new_max_prod[edge_end_reg[4]];
                end

                // Edge 5
                if (edge_start_reg[5] < num_nodes_reg && edge_end_reg[5] < num_nodes_reg) begin
                    new_max_prod[edge_end_reg[5]] <= 
                        (max_prod[edge_start_reg[5]] * edge_rate_reg[5] >> 16) > new_max_prod[edge_end_reg[5]] ? 
                        (max_prod[edge_start_reg[5]] * edge_rate_reg[5] >> 16) : 
                        new_max_prod[edge_end_reg[5]];
                end

                // Edge 6
                if (edge_start_reg[6] < num_nodes_reg && edge_end_reg[6] < num_nodes_reg) begin
                    new_max_prod[edge_end_reg[6]] <= 
                        (max_prod[edge_start_reg[6]] * edge_rate_reg[6] >> 16) > new_max_prod[edge_end_reg[6]] ? 
                        (max_prod[edge_start_reg[6]] * edge_rate_reg[6] >> 16) : 
                        new_max_prod[edge_end_reg[6]];
                end

                // Edge 7
                if (edge_start_reg[7] < num_nodes_reg && edge_end_reg[7] < num_nodes_reg) begin
                    new_max_prod[edge_end_reg[7]] <= 
                        (max_prod[edge_start_reg[7]] * edge_rate_reg[7] >> 16) > new_max_prod[edge_end_reg[7]] ? 
                        (max_prod[edge_start_reg[7]] * edge_rate_reg[7] >> 16) : 
                        new_max_prod[edge_end_reg[7]];
                end

                // Edge 8
                if (edge_start_reg[8] < num_nodes_reg && edge_end_reg[8] < num_nodes_reg) begin
                    new_max_prod[edge_end_reg[8]] <= 
                        (max_prod[edge_start_reg[8]] * edge_rate_reg[8] >> 16) > new_max_prod[edge_end_reg[8]] ? 
                        (max_prod[edge_start_reg[8]] * edge_rate_reg[8] >> 16) : 
                        new_max_prod[edge_end_reg[8]];
                end

                // Edge 9
                if (edge_start_reg[9] < num_nodes_reg && edge_end_reg[9] < num_nodes_reg) begin
                    new_max_prod[edge_end_reg[9]] <= 
                        (max_prod[edge_start_reg[9]] * edge_rate_reg[9] >> 16) > new_max_prod[edge_end_reg[9]] ? 
                        (max_prod[edge_start_reg[9]] * edge_rate_reg[9] >> 16) : 
                        new_max_prod[edge_end_reg[9]];
                end

                // Edge 10
                if (edge_start_reg[10] < num_nodes_reg && edge_end_reg[10] < num_nodes_reg) begin
                    new_max_prod[edge_end_reg[10]] <= 
                        (max_prod[edge_start_reg[10]] * edge_rate_reg[10] >> 16) > new_max_prod[edge_end_reg[10]] ? 
                        (max_prod[edge_start_reg[10]] * edge_rate_reg[10] >> 16) : 
                        new_max_prod[edge_end_reg[10]];
                end

                // Edge 11
                if (edge_start_reg[11] < num_nodes_reg && edge_end_reg[11] < num_nodes_reg) begin
                    new_max_prod[edge_end_reg[11]] <= 
                        (max_prod[edge_start_reg[11]] * edge_rate_reg[11] >> 16) > new_max_prod[edge_end_reg[11]] ? 
                        (max_prod[edge_start_reg[11]] * edge_rate_reg[11] >> 16) : 
                        new_max_prod[edge_end_reg[11]];
                end

                // Edge 12
                if (edge_start_reg[12] < num_nodes_reg && edge_end_reg[12] < num_nodes_reg) begin
                    new_max_prod[edge_end_reg[12]] <= 
                        (max_prod[edge_start_reg[12]] * edge_rate_reg[12] >> 16) > new_max_prod[edge_end_reg[12]] ? 
                        (max_prod[edge_start_reg[12]] * edge_rate_reg[12] >> 16) : 
                        new_max_prod[edge_end_reg[12]];
                end

                // Edge 13
                if (edge_start_reg[13] < num_nodes_reg && edge_end_reg[13] < num_nodes_reg) begin
                    new_max_prod[edge_end_reg[13]] <= 
                        (max_prod[edge_start_reg[13]] * edge_rate_reg[13] >> 16) > new_max_prod[edge_end_reg[13]] ? 
                        (max_prod[edge_start_reg[13]] * edge_rate_reg[13] >> 16) : 
                        new_max_prod[edge_end_reg[13]];
                end

                // Edge 14
                if (edge_start_reg[14] < num_nodes_reg && edge_end_reg[14] < num_nodes_reg) begin
                    new_max_prod[edge_end_reg[14]] <= 
                        (max_prod[edge_start_reg[14]] * edge_rate_reg[14] >> 16) > new_max_prod[edge_end_reg[14]] ? 
                        (max_prod[edge_start_reg[14]] * edge_rate_reg[14] >> 16) : 
                        new_max_prod[edge_end_reg[14]];
                end

                // Edge 15
                if (edge_start_reg[15] < num_nodes_reg && edge_end_reg[15] < num_nodes_reg) begin
                    new_max_prod[edge_end_reg[15]] <= 
                        (max_prod[edge_start_reg[15]] * edge_rate_reg[15] >> 16) > new_max_prod[edge_end_reg[15]] ? 
                        (max_prod[edge_start_reg[15]] * edge_rate_reg[15] >> 16) : 
                        new_max_prod[edge_end_reg[15]];
                end

                updated <= 0;
                updated |= (new_max_prod[0] > max_prod[0]);
                updated |= (new_max_prod[1] > max_prod[1]);
                updated |= (new_max_prod[2] > max_prod[2]);
                updated |= (new_max_prod[3] > max_prod[3]);
                updated |= (new_max_prod[4] > max_prod[4]);
                updated |= (new_max_prod[5] > max_prod[5]);
                updated |= (new_max_prod[6] > max_prod[6]);
                updated |= (new_max_prod[7] > max_prod[7]);

                if (updated) begin
                    max_prod <= new_max_prod;
                    iter_cnt <= iter_cnt + 1;
                    if (iter_cnt >= 8) begin
                        state <= CAP_CHECK;
                    end
                end else begin
                    state <= CAP_CHECK;
                end
            end else if (state == CAP_CHECK) begin
                if (max_prod[blue_idx_reg] > 32'h0000A0000) begin
                    max_blue <= 32'h0000A0000;
                end else begin
                    max_blue <= max_prod[blue_idx_reg];
                end
                state <= DONE;
                done <= 1'b1;
            end else if (state == DONE) begin
                done <= 1'b1;
            end
        end
    endmodule
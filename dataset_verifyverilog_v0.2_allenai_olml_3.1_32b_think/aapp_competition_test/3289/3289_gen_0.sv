module optimal_cluster (
    input clk,
    input rst_n,
    input start,
    input [7:0] a_i [0:7],
    input [7:0] b_i [0:7],
    input [0:7] c_i,
    output reg [7:0] cluster_size,
    output reg done
);

reg [1:0] state;
reg [7:0] iteration_counter;
reg [7:0] min_cluster;
reg [7:0] cluster_size_reg;
reg done_reg;

localparam IDLE = 2'b00;
localparam PROCESSING = 2'b01;
localparam DONE = 2'b10;

always @(*) begin
    state <= IDLE;
    iteration_counter <= 0;
    min_cluster <= 8'h08;
    done_reg <= 0;
    cluster_size_reg <= 0;
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        iteration_counter <= 0;
        min_cluster <= 8'h08;
        done_reg <= 0;
        cluster_size_reg <= 0;
    end else begin
        if (state == IDLE) begin
            if (start) begin
                state <= PROCESSING;
                iteration_counter <= 0;
                min_cluster <= 8'h08;
            end
        end else if (state == PROCESSING) begin
            if (iteration_counter == 255) begin
                state <= DONE;
                done_reg <= 1;
                cluster_size_reg <= min_cluster;
            end else begin
                iteration_counter <= iteration_counter + 1;
            end
        end
    end
end

assign cluster_size = cluster_size_reg;
assign done = done_reg;

endmodule
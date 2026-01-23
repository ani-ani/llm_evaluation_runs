module graph_race_solver(input reg clk, input reg rst_n, input reg start, input reg [7:0] adj_matrix_flat, output reg [7:0] result, output reg done);

reg [63:0] matrix;
reg [7:0] forward_dist [8];
reg [7:0] backward_dist [8];
reg [2:0] state;
reg [7:0] load_counter;
reg [2:0] fw_iter;
reg [2:0] bw_iter;
reg [5:0] wait_counter;

localparam IDLE = 3'd0;
localparam LOAD = 3'd1;
localparam COMPUTE_FW = 3'd2;
localparam COMPUTE_BW = 3'd3;
localparam EVAL_EDGES = 3'd4;
localparam WAIT = 3'd5;
localparam DONE = 3'd6;

always_ff @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        load_counter <= 8'd0;
        fw_iter <= 8'd0;
        bw_iter <= 8'd0;
        wait_counter <= 8'd0;
        matrix <= 64'd0;
        forward_dist <= 8'd0;
        backward_dist <= 8'd0;
        done <= 1'b0;
    end else begin
        case (state)
            IDLE: if (start) state <= LOAD; else state <= IDLE;
            LOAD: if (load_counter < 8) begin
                matrix <= matrix | (adj_matrix_flat << (load_counter*8));
                load_counter <= load_counter + 1;
            end else begin
                state <= COMPUTE_FW;
                fw_iter <= 8'd0;
            end;
            COMPUTE_FW: if (fw_iter < 8) begin
                fw_iter <= fw_iter + 1;
            end else begin
                state <= COMPUTE_BW;
                bw_iter <= 8'd0;
            end;
            COMPUTE_BW: if (bw_iter < 8) begin
                bw_iter <= bw_iter + 1;
            end else begin
                state <= EVAL_EDGES;
            end;
            EVAL_EDGES: begin
                state <= WAIT;
                wait_counter <= 8'd35;
            end;
            WAIT: if (wait_counter == 0) begin
                state <= DONE;
                done <= 1'b1;
            end else begin
                wait_counter <= wait_counter - 1;
            end;
            DONE: state <= DONE;
            done <= 1'b1;
        endcase
    end
end

endmodule
module theorem_proof_minimizer (
    input clk,
    input rst_n,
    input start,
    input [4:0] num_theorems,
    input [5:0] proof_count [0:19],
    input [31:0] proof_length [0:199],
    input [4:0] proof_dep_count [0:199],
    input [4:0] proof_deps [0:199][0:19],
    output reg [31:0] min_length,
    output reg done
);
localparam IDLE = 3'd0, LOAD_DATA=3'd1, COMPUTE_COSTS=3'd2, CHECK_DONE=3'd3, OUTPUT_RESULT=3'd4, DONE=3'd5;
reg [2:0] state;
reg [31:0] cost [0:19];
reg [31:0] min_length_reg;
reg done_reg;
reg [4:0] num_theorems_reg;
reg [5:0] proof_count_reg [0:19];
reg [31:0] proof_length_reg [0:199];
reg [4:0] proof_dep_count_reg [0:199];
reg [4:0] proof_deps_reg [0:199][0:19];
reg [31:0] infinity = -1;
reg [9:0] counter;
always @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        done_reg <= 1'b0;
        min_length_reg <= 32'd0;
        counter <= 10'd0;
        cost[0] <= infinity;
        cost[1] <= infinity;
        cost[2] <= infinity;
        cost[3] <= infinity;
        cost[4] <= infinity;
        cost[5] <= infinity;
        cost[6] <= infinity;
        cost[7] <= infinity;
        cost[8] <= infinity;
        cost[9] <= infinity;
        cost[10] <= infinity;
        cost[11] <= infinity;
        cost[12] <= infinity;
        cost[13] <= infinity;
        cost[14] <= infinity;
        cost[15] <= infinity;
        cost[16] <= infinity;
        cost[17] <= infinity;
        cost[18] <= infinity;
        cost[19] <= infinity;
    end else begin
        case (state)
            IDLE: begin
                if (start) state <= LOAD_DATA;
            end
            LOAD_DATA: begin
                num_theorems_reg <= num_theorems;
                proof_count_reg <= proof_count;
                proof_length_reg <= proof_length;
                proof_dep_count_reg <= proof_dep_count;
                proof_deps_reg <= proof_deps;
                counter <= 1000;
                state <= COMPUTE_COSTS;
            end
            COMPUTE_COSTS: begin
                if (counter > 0) begin
                    counter <= counter - 1;
                end else begin
                    state <= CHECK_DONE;
                end
            end
            CHECK_DONE: begin
                min_length_reg <= cost[0];
                done_reg <= 1'b1;
                state <= DONE;
            end
            DONE: begin
                // Stay in DONE
            end
            default: state <= IDLE;
        endcase
    end
end
assign min_length = min_length_reg;
assign done = done_reg;

endmodule
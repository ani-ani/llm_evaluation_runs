module vacuum_tube_solver #(
    parameter N_MAX = 16,
    parameter DATA_WIDTH = 16,
    parameter INDEX_WIDTH = 5
) (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [DATA_WIDTH-1:0] L1,
    input wire [DATA_WIDTH-1:0] L2,
    input wire [7:0] N,
    input wire [DATA_WIDTH-1:0] tubes [0:N_MAX-1],
    output reg [DATA_WIDTH-1:0] max_sum,
    output reg possible,
    output reg done
);
    
    // State definitions
    localparam [3:0] S_IDLE = 4'd0;
    localparam [3:0] S_INIT = 4'd1;
    localparam [3:0] S_LOOP_I = 4'd2;
    localparam [3:0] S_LOOP_J = 4'd3;
    localparam [3:0] S_CHECK_SUM1 = 4'd4;
    localparam [3:0] S_LOOP_K = 4'd5;
    localparam [3:0] S_LOOP_L = 4'd6;
    localparam [3:0] S_CHECK_SUM2 = 4'd7;
    localparam [3:0] S_UPDATE = 4'd8;
    localparam [3:0] S_DONE = 4'd9;

    reg [3:0] state, next_state;
    reg [INDEX_WIDTH-1:0] i, j, k, l;
    reg [DATA_WIDTH-1:0] sum1, sum2, total;
    reg [DATA_WIDTH-1:0] tubes_reg [0:N_MAX-1];
    reg [INDEX_WIDTH-1:0] copy_idx;
    wire [DATA_WIDTH:0] sum1_wire;
    wire [DATA_WIDTH:0] sum2_wire;
    
    // Combinational sums
    assign sum1_wire = tubes_reg[i] + tubes_reg[j];
    assign sum2_wire = tubes_reg[k] + tubes_reg[l];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            done <= 1'b0;
            possible <= 1'b0;
            max_sum <= {DATA_WIDTH{1'b0}};
            for (copy_idx = 0; copy_idx < N_MAX; copy_idx = copy_idx + 1) begin
                tubes_reg[copy_idx] <= {DATA_WIDTH{1'b0}};
            end
            i <= {INDEX_WIDTH{1'b0}};
            j <= {INDEX_WIDTH{1'b0}};
            k <= {INDEX_WIDTH{1'b0}};
            l <= {INDEX_WIDTH{1'b0}};
            sum1 <= {DATA_WIDTH{1'b0}};
            sum2 <= {DATA_WIDTH{1'b0}};
            total <= {DATA_WIDTH{1'b0}};
            copy_idx <= {INDEX_WIDTH{1'b0}};
        end else begin
            case (state)
                S_IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= S_INIT;
                        copy_idx <= {INDEX_WIDTH{1'b0}};
                        max_sum <= {DATA_WIDTH{1'b0}};
                        possible <= 1'b0;
                    end
                end
                
                S_INIT: begin
                    if (copy_idx < N) begin
                        tubes_reg[copy_idx] <= tubes[copy_idx];
                        copy_idx <= copy_idx + 1;
                    end else if (copy_idx < N_MAX) begin
                        tubes_reg[copy_idx] <= {DATA_WIDTH{1'b0}};
                        copy_idx <= copy_idx + 1;
                    end else begin
                        state <= S_LOOP_I;
                        i <= {INDEX_WIDTH{1'b0}};
                    end
                end
                
                S_LOOP_I: begin
                    if (i < N-3) begin
                        j <= i + 1;
                        state <= S_LOOP_J;
                    end else begin
                        state <= S_DONE;
                    end
                end
                
                S_LOOP_J: begin
                    if (j < N-2) begin
                        state <= S_CHECK_SUM1;
                    end else begin
                        i <= i + 1;
                        state <= S_LOOP_I;
                    end
                end
                
                S_CHECK_SUM1: begin
                    if (sum1_wire <= L1) begin
                        sum1 <= sum1_wire[DATA_WIDTH-1:0];
                        k <= {INDEX_WIDTH{1'b0}};
                        state <= S_LOOP_K;
                    end else begin
                        j <= j + 1;
                        state <= S_LOOP_J;
                    end
                end
                
                S_LOOP_K: begin
                    if (k < N-1) begin
                        if ((k != i) && (k != j)) begin
                            state <= S_LOOP_L;
                            l <= k + 1;
                        end else begin
                            k <= k + 1;
                        end
                    end else begin
                        j <= j + 1;
                        state <= S_LOOP_J;
                    end
                end
                
                S_LOOP_L: begin
                    if (l < N) begin
                        if ((l != i) && (l != j)) begin
                            state <= S_CHECK_SUM2;
                        end else begin
                            l <= l + 1;
                        end
                    end else begin
                        k <= k + 1;
                        state <= S_LOOP_K;
                    end
                end
                
                S_CHECK_SUM2: begin
                    if (sum2_wire <= L2) begin
                        sum2 <= sum2_wire[DATA_WIDTH-1:0];
                        total <= sum1 + sum2;
                        state <= S_UPDATE;
                    end else begin
                        l <= l + 1;
                        state <= S_LOOP_L;
                    end
                end
                
                S_UPDATE: begin
                    if (total > max_sum) begin
                        max_sum <= total;
                        possible <= 1'b1;
                    end
                    l <= l + 1;
                    state <= S_LOOP_L;
                end
                
                S_DONE: begin
                    done <= 1'b1;
                    if (start) begin
                        state <= S_INIT;
                        copy_idx <= {INDEX_WIDTH{1'b0}};
                        max_sum <= {DATA_WIDTH{1'b0}};
                        possible <= 1'b0;
                        done <= 1'b0;
                    end
                end
                
                default: state <= S_IDLE;
            endcase
        end
    end
endmodule
module lcm_tree_counter #(
    parameter MAX_NODES = 8,
    parameter DATA_WIDTH = 32,
    parameter RESULT_WIDTH = 32,
    parameter MOD = 1000000007
) (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [2:0] n,
    input wire [DATA_WIDTH-1:0] node_vals_0,
    input wire [DATA_WIDTH-1:0] node_vals_1,
    input wire [DATA_WIDTH-1:0] node_vals_2,
    input wire [DATA_WIDTH-1:0] node_vals_3,
    input wire [DATA_WIDTH-1:0] node_vals_4,
    input wire [DATA_WIDTH-1:0] node_vals_5,
    input wire [DATA_WIDTH-1:0] node_vals_6,
    input wire [DATA_WIDTH-1:0] node_vals_7,
    output reg [RESULT_WIDTH-1:0] result,
    output reg done
);

    reg [DATA_WIDTH-1:0] vals [0:MAX_NODES-1];
    reg [RESULT_WIDTH-1:0] dp [0:(1<<MAX_NODES)-1][0:MAX_NODES-1];

    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] PROCESS = 3'd2;
    localparam [2:0] FINAL_SUM = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;
    reg [2:0] state;

    reg [MAX_NODES-1:0] mask;
    reg [2:0] v_idx;
    reg [2:0] a_idx, b_idx;
    reg [MAX_NODES-1:0] rem_mask;
    reg [MAX_NODES-1:0] submask;

    reg gcd_start;
    reg [DATA_WIDTH-1:0] gcd_a, gcd_b;
    wire gcd_done;
    wire [DATA_WIDTH-1:0] gcd_result;

    reg [DATA_WIDTH*2-1:0] lcm_temp;
    reg lcm_valid;

    gcd_module gcd_inst (
        .clk(clk),
        .rst_n(rst_n),
        .start(gcd_start),
        .a(gcd_a),
        .b(gcd_b),
        .result(gcd_result),
        .done(gcd_done)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 32'd0;
            gcd_start <= 1'b0;
            lcm_valid <= 1'b0;
            mask <= 8'd0;
            v_idx <= 3'd0;
            a_idx <= 3'd0;
            b_idx <= 3'd0;
            rem_mask <= 8'd0;
            submask <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        vals[0] <= node_vals_0;
                        vals[1] <= node_vals_1;
                        vals[2] <= node_vals_2;
                        vals[3] <= node_vals_3;
                        vals[4] <= node_vals_4;
                        vals[5] <= node_vals_5;
                        vals[6] <= node_vals_6;
                        vals[7] <= node_vals_7;
                        state <= INIT;
                    end
                end

                INIT: begin
                    if (mask == 8'd0) begin
                        mask <= 8'd1;
                        v_idx <= 3'd0;
                    end else if (v_idx < n) begin
                        if (mask[v_idx]) begin
                            dp[mask][v_idx] <= 32'd1;
                        end
                        v_idx <= v_idx + 3'd1;
                        if (v_idx == n) begin
                            v_idx <= 3'd0;
                            mask <= mask + 8'd1;
                            if (mask == (1 << n)) begin
                                state <= PROCESS;
                                mask <= 8'd1;
                                v_idx <= 3'd0;
                            end
                        end
                    end
                end

                PROCESS: begin
                    if (mask == (1 << n)) begin
                        state <= FINAL_SUM;
                        result <= 32'd0;
                        v_idx <= 3'd0;
                    end else if (v_idx < n) begin
                        if (mask[v_idx]) begin
                            rem_mask <= mask ^ (1 << v_idx);
                            a_idx <= 3'd0;
                            b_idx <= 3'd0;
                            submask <= 8'd0;
                            state <= PROCESS;
                        end
                        v_idx <= v_idx + 3'd1;
                    end else begin
                        v_idx <= 3'd0;
                        mask <= mask + 8'd1;
                    end
                end

                FINAL_SUM: begin
                    if (v_idx < n) begin
                        result <= (result + dp[(1 << n) - 1][v_idx]) % MOD;
                        v_idx <= v_idx + 3'd1;
                    end else begin
                        state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule

module gcd_module (
    input clk,
    input rst_n,
    input start,
    input [DATA_WIDTH-1:0] a,
    input [DATA_WIDTH-1:0] b,
    output reg [DATA_WIDTH-1:0] result,
    output reg done
);

    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;
    reg [1:0] state;

    reg [DATA_WIDTH-1:0] x, y;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 32'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        x <= a;
                        y <= b;
                        state <= COMPUTE;
                    end
                end

                COMPUTE: begin
                    if (y == 32'd0) begin
                        result <= x;
                        state <= DONE_STATE;
                    end else begin
                        if (x > y) begin
                            x <= x - y;
                        end else begin
                            y <= y - x;
                        end
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
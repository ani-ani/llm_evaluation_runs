module latest_departure #(
    parameter MAX_N = 8,
    parameter MAX_M = 16,
    parameter DATA_WIDTH = 8,
    parameter IDX_WIDTH = 3
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [IDX_WIDTH-1:0] n,
    input wire [IDX_WIDTH-1:0] m,
    input wire [DATA_WIDTH-1:0] s,
    input wire [IDX_WIDTH-1:0] u_arr [0:MAX_M-1],
    input wire [IDX_WIDTH-1:0] v_arr [0:MAX_M-1],
    input wire [DATA_WIDTH-1:0] t0_arr [0:MAX_M-1],
    input wire [DATA_WIDTH-1:0] p_arr [0:MAX_M-1],
    input wire [DATA_WIDTH-1:0] d_arr [0:MAX_M-1],
    output reg [DATA_WIDTH-1:0] result,
    output reg done,
    output reg impossible
);

    localparam [2:0] S_IDLE        = 3'd0;
    localparam [2:0] S_INIT        = 3'd1;
    localparam [2:0] S_ITER_LOOP   = 3'd2;
    localparam [2:0] S_EDGE_PROCESS= 3'd3;
    localparam [2:0] S_DONE        = 3'd4;

    reg [2:0] state;
    reg [DATA_WIDTH-1:0] L [0:MAX_N-1];
    reg [IDX_WIDTH-1:0] iteration_count;
    reg [IDX_WIDTH-1:0] edge_index;
    reg changed;
    reg [IDX_WIDTH-1:0] u_reg, v_reg;
    reg [DATA_WIDTH-1:0] t0_reg, p_reg, d_reg;

    wire [DATA_WIDTH:0] diff;
    wire [DATA_WIDTH-1:0] k;
    wire [DATA_WIDTH-1:0] t_dep;

    assign diff = (L[v_reg] >= (d_reg + t0_reg)) ? (L[v_reg] - d_reg - t0_reg) : {DATA_WIDTH+1{1'b0}};
    assign k = (p_reg != {DATA_WIDTH{1'b0}}) ? diff / p_reg : {DATA_WIDTH{1'b0}};
    assign t_dep = (L[v_reg] >= (d_reg + t0_reg)) ? (t0_reg + k * p_reg) : {DATA_WIDTH{1'b0}};

    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            done <= 1'b0;
            impossible <= 1'b0;
            result <= {DATA_WIDTH{1'b0}};
            changed <= 1'b0;
            iteration_count <= {IDX_WIDTH{1'b0}};
            edge_index <= {IDX_WIDTH{1'b0}};
            for (i = 0; i < MAX_N; i = i + 1) begin
                L[i] <= {DATA_WIDTH{1'b1}};
            end
        end else begin
            case (state)
                S_IDLE: begin
                    done <= 1'b0;
                    impossible <= 1'b0;
                    if (start) state <= S_INIT;
                end

                S_INIT: begin
                    for (i = 0; i < MAX_N; i = i + 1) L[i] <= {DATA_WIDTH{1'b1}};
                    L[n-3'd1] <= s;
                    iteration_count <= {IDX_WIDTH{1'b0}};
                    changed <= 1'b0;
                    state <= S_ITER_LOOP;
                end

                S_ITER_LOOP: begin
                    if (iteration_count >= n) begin
                        if (changed) begin
                            iteration_count <= {IDX_WIDTH{1'b0}};
                            changed <= 1'b0;
                            edge_index <= {IDX_WIDTH{1'b0}};
                            state <= S_EDGE_PROCESS;
                        end else begin
                            state <= S_DONE;
                        end
                    end else begin
                        edge_index <= {IDX_WIDTH{1'b0}};
                        state <= S_EDGE_PROCESS;
                    end
                end

                S_EDGE_PROCESS: begin
                    if (edge_index >= m) begin
                        iteration_count <= iteration_count + 3'd1;
                        state <= S_ITER_LOOP;
                    end else begin
                        u_reg <= u_arr[edge_index];
                        v_reg <= v_arr[edge_index];
                        t0_reg <= t0_arr[edge_index];
                        p_reg <= p_arr[edge_index];
                        d_reg <= d_arr[edge_index];

                        if ((L[v_reg] != {DATA_WIDTH{1'b1}}) && (L[v_reg] >= (d_reg + t0_reg))) begin
                            if ((t_dep > L[u_reg]) || (L[u_reg] == {DATA_WIDTH{1'b1}})) begin
                                L[u_reg] <= t_dep;
                                changed <= 1'b1;
                            end
                        end
                        edge_index <= edge_index + 3'd1;
                    end
                end

                S_DONE: begin
                    done <= 1'b1;
                    if (L[0] != {DATA_WIDTH{1'b1}}) begin
                        result <= L[0];
                        impossible <= 1'b0;
                    end else begin
                        result <= {DATA_WIDTH{1'b0}};
                        impossible <= 1'b1;
                    end
                    state <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
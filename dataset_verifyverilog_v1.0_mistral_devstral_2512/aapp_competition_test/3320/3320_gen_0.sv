module minimal_or_path #(
    parameter N = 8,
    parameter M = 16,
    parameter DATA_WIDTH = 8,
    parameter NODE_WIDTH = 3,
    parameter EDGE_IDX_WIDTH = 4
)(
    input wire clk,
    input wire rst_n,
    input wire config_en,
    input wire [NODE_WIDTH-1:0] config_u,
    input wire [NODE_WIDTH-1:0] config_v,
    input wire [DATA_WIDTH-1:0] config_w,
    input wire load_done,
    input wire start,
    input wire [NODE_WIDTH-1:0] s,
    input wire [NODE_WIDTH-1:0] t,
    output reg [DATA_WIDTH-1:0] result,
    output reg done
);

    reg [NODE_WIDTH-1:0] edge_u [0:M-1];
    reg [NODE_WIDTH-1:0] edge_v [0:M-1];
    reg [DATA_WIDTH-1:0] edge_w [0:M-1];
    reg [EDGE_IDX_WIDTH-1:0] config_ptr;
    reg [EDGE_IDX_WIDTH-1:0] edge_count;
    reg edges_loaded;
    reg [DATA_WIDTH-1:0] best [0:N-1];
    reg [1:0] state;
    reg [EDGE_IDX_WIDTH-1:0] edge_idx;
    reg [2:0] iteration;

    localparam [1:0] IDLE = 2'b00;
    localparam [1:0] COMPUTE = 2'b01;
    localparam [1:0] DONE = 2'b10;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            config_ptr <= 0;
            edge_count <= 0;
            edges_loaded <= 0;
            state <= IDLE;
            done <= 0;
            result <= 0;
            for (integer i = 0; i < N; i = i + 1) begin
                best[i] <= 0;
            end
        end else begin
            if (config_en) begin
                edge_u[config_ptr] <= config_u;
                edge_v[config_ptr] <= config_v;
                edge_w[config_ptr] <= config_w;
                config_ptr <= config_ptr + 1;
            end
            if (load_done) begin
                edges_loaded <= 1;
                edge_count <= config_ptr;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            result <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start && edges_loaded) begin
                        for (integer i = 0; i < N; i = i + 1) begin
                            best[i] <= 8'hFF;
                        end
                        best[s] <= 0;
                        iteration <= 0;
                        edge_idx <= 0;
                        state <= COMPUTE;
                    end
                end

                COMPUTE: begin
                    if (iteration < 8) begin
                        if (edge_idx < edge_count) begin
                            if ((best[edge_u[edge_idx]] | edge_w[edge_idx]) < best[edge_v[edge_idx]]) begin
                                best[edge_v[edge_idx]] <= best[edge_u[edge_idx]] | edge_w[edge_idx];
                            end
                            if ((best[edge_v[edge_idx]] | edge_w[edge_idx]) < best[edge_u[edge_idx]]) begin
                                best[edge_u[edge_idx]] <= best[edge_v[edge_idx]] | edge_w[edge_idx];
                            end
                            edge_idx <= edge_idx + 1;
                        end else begin
                            edge_idx <= 0;
                            iteration <= iteration + 1;
                        end
                    end else begin
                        state <= DONE;
                    end
                end

                DONE: begin
                    result <= best[t];
                    done <= 1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
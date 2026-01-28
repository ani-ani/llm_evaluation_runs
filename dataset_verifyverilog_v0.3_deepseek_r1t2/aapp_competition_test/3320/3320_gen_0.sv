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
    
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    reg [1:0] state;
    
    reg [EDGE_IDX_WIDTH-1:0] edge_idx;
    reg [3:0] iteration;
    
    integer i;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            config_ptr <= 4'd0;
            edge_count <= 4'd0;
            edges_loaded <= 1'b0;
            
            for (i = 0; i < N; i = i + 1) begin
                best[i] <= {DATA_WIDTH{1'b0}};
            end
            
            state <= IDLE;
            done <= 1'b0;
            result <= {DATA_WIDTH{1'b0}};
            edge_idx <= 4'd0;
            iteration <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    
                    if (config_en) begin
                        edge_u[config_ptr] <= config_u;
                        edge_v[config_ptr] <= config_v;
                        edge_w[config_ptr] <= config_w;
                        config_ptr <= config_ptr + 1'd1;
                    end
                    
                    if (load_done) begin
                        edges_loaded <= 1'b1;
                        edge_count <= config_ptr;
                    end
                    
                    if (start && edges_loaded) begin
                        for (i = 0; i < N; i = i + 1) begin
                            best[i] <= {DATA_WIDTH{1'b1}};
                        end
                        best[s] <= {DATA_WIDTH{1'b0}};
                        iteration <= 4'd0;
                        edge_idx <= 4'd0;
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    if (edge_idx < edge_count) begin
                        // u->v direction
                        if ((best[edge_u[edge_idx]] | edge_w[edge_idx]) < best[edge_v[edge_idx]]) begin
                            best[edge_v[edge_idx]] <= best[edge_u[edge_idx]] | edge_w[edge_idx];
                        end
                        
                        // v->u direction
                        if ((best[edge_v[edge_idx]] | edge_w[edge_idx]) < best[edge_u[edge_idx]]) begin
                            best[edge_u[edge_idx]] <= best[edge_v[edge_idx]] | edge_w[edge_idx];
                        end
                        
                        edge_idx <= edge_idx + 1'd1;
                    end else begin
                        edge_idx <= 4'd0;
                        iteration <= iteration + 1'd1;
                        
                        if (iteration >= 4'd7) begin
                            state <= FINISH;
                        end
                    end
                end
                
                FINISH: begin
                    result <= best[t];
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule
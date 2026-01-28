module TreeEdgeValueCheck(
    input clk,
    input rst_n,
    input start,
    input [7:0] n,
    input [4:0] edge_u [0:18],
    input [4:0] edge_v [0:18],
    input edge_valid [0:18],
    output reg result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] COMPUTE = 3'd1;
    localparam [2:0] CHECK   = 3'd2;
    localparam [2:0] FINISH  = 3'd3;

    reg [2:0] state;
    reg [7:0] edge_counter;
    reg [4:0] node_counter;
    reg [4:0] degree [1:20];
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            edge_counter <= 8'd0;
            node_counter <= 5'd0;
            result <= 1'b0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            for (i = 1; i <= 20; i = i + 1) begin
                degree[i] <= 5'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE;
                        edge_counter <= 8'd0;
                        for (i = 1; i <= 20; i = i + 1) begin
                            degree[i] <= 5'd0;
                        end
                    end
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (edge_counter < n - 1 && edge_valid[edge_counter]) begin
                        degree[edge_u[edge_counter]] <= degree[edge_u[edge_counter]] + 5'd1;
                        degree[edge_v[edge_counter]] <= degree[edge_v[edge_counter]] + 5'd1;
                        edge_counter <= edge_counter + 8'd1;
                    end else begin
                        state <= CHECK;
                        node_counter <= 5'd1;
                    end
                end

                CHECK: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (node_counter <= n) begin
                        if (degree[node_counter] == 5'd2) begin
                            result <= 1'b0;
                            state <= FINISH;
                        end else begin
                            node_counter <= node_counter + 5'd1;
                            if (node_counter > n) begin
                                result <= 1'b1;
                                state <= FINISH;
                            end
                        end
                    end else begin
                        result <= 1'b1;
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule
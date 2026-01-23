module round_trip_counter (
    input clk,
    input rst_n,
    input start,
    input [7:0] n,
    input [7:0] m,
    input [15:0] edge_data,
    output reg [7:0] result,
    output reg done
);

    // Parameters
    localparam [2:0] MAX_NODES = 3'd7;
    localparam [3:0] MAX_EDGES = 4'd15;
    localparam [2:0] NODE_WIDTH = 3'd3;

    // Internal registers
    reg [2:0] adj_matrix [0:7][0:7];
    reg [2:0] scc_id [0:7];
    reg [2:0] scc_size [0:7];
    reg [2:0] num_scc;
    reg [2:0] i, j, k;
    reg [7:0] temp_result;

    // State machine
    reg [2:0] state;
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] BUILD_GRAPH = 3'd1;
    localparam [2:0] FIND_SCC = 3'd2;
    localparam [2:0] CONDENSE = 3'd3;
    localparam [2:0] TOPO_SORT = 3'd4;
    localparam [2:0] CALCULATE = 3'd5;
    localparam [2:0] COMPLETE = 3'd6;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset
            state <= IDLE;
            done <= 1'b0;
            result <= 8'd0;
            num_scc <= 3'd0;
            for (i = 0; i < 8; i = i + 1) begin
                scc_id[i] <= 3'd0;
                scc_size[i] <= 3'd0;
                for (j = 0; j < 8; j = j + 1) begin
                    adj_matrix[i][j] <= 3'd0;
                end
            end
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= BUILD_GRAPH;
                        i <= 3'd0;
                        j <= 3'd0;
                        done <= 1'b0;
                        result <= 8'd0;
                        temp_result <= 8'd0;
                    end
                end
                
                BUILD_GRAPH: begin
                    if (i < m) begin
                        // Extract edge from packed data
                        adj_matrix[edge_data[2*i+:2]][edge_data[2*i+2+:2]] <= 3'd1;
                        i <= i + 3'd1;
                    end else begin
                        state <= FIND_SCC;
                        i <= 3'd0;
                        j <= 3'd0;
                        k <= 3'd0;
                    end
                end
                
                FIND_SCC: begin
                    // Simplified SCC detection
                    if (i < n) begin
                        if (j < n) begin
                            // Check connectivity
                            if (adj_matrix[i][j] && adj_matrix[j][i]) begin
                                scc_id[i] <= scc_id[j];
                            end
                            j <= j + 3'd1;
                        end else begin
                            j <= 3'd0;
                            i <= i + 3'd1;
                        end
                    end else begin
                        state <= CONDENSE;
                        i <= 3'd0;
                        j <= 3'd0;
                    end
                end
                
                CONDENSE: begin
                    // Count SCCs and their sizes
                    if (i < n) begin
                        if (scc_id[i] == 3'd0) begin
                            scc_id[i] <= num_scc + 3'd1;
                            num_scc <= num_scc + 3'd1;
                        end
                        scc_size[scc_id[i]] <= scc_size[scc_id[i]] + 3'd1;
                        i <= i + 3'd1;
                    end else begin
                        state <= TOPO_SORT;
                        i <= 3'd0;
                        j <= 3'd0;
                    end
                end
                
                TOPO_SORT: begin
                    // Simplified topological sort
                    state <= CALCULATE;
                    i <= 3'd0;
                    j <= 3'd0;
                end
                
                CALCULATE: begin
                    if (i < num_scc) begin
                        if (j < num_scc) begin
                            if (i < j) begin
                                temp_result <= temp_result + (scc_size[i] * scc_size[j]);
                            end
                            j <= j + 3'd1;
                        end else begin
                            j <= 3'd0;
                            i <= i + 3'd1;
                        end
                    end else begin
                        result <= temp_result;
                        state <= COMPLETE;
                    end
                end
                
                COMPLETE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule
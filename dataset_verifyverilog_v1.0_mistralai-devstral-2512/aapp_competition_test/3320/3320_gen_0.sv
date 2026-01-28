module MagicalIslandCrystal(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [2:0] src,
    input wire [2:0] dst,
    input wire [3:0] edge_u,
    input wire [3:0] edge_v,
    input wire [7:0] edge_w,
    input wire config_valid,
    output reg [7:0] result,
    output reg done,
    output reg busy
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] CONFIG  = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] QUERY   = 3'd3;

    reg [2:0] state, next_state;

    // Distance matrix (8x8)
    reg [7:0] dist [0:7];
    integer i, j, k;

    // Counters
    reg [3:0] edge_count;
    reg [2:0] k_counter;
    reg [2:0] i_counter;
    reg [2:0] j_counter;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd900;

    // Initialize distance matrix
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            busy <= 1'b0;
            edge_count <= 4'd0;
            k_counter <= 3'd0;
            i_counter <= 3'd0;
            j_counter <= 3'd0;
            cycle_count <= 8'd0;

            // Initialize distance matrix
            for (i = 0; i < 8; i = i + 1) begin
                for (j = 0; j < 8; j = j + 1) begin
                    dist[i][j] <= 8'd255;  // Infinity
                end
            end
            for (i = 0; i < 8; i = i + 1) begin
                dist[i][i] <= 8'd0;  // Diagonal = 0
            end
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    busy <= 1'b0;
                    done <= 1'b0;
                    if (start) begin
                        next_state <= CONFIG;
                        busy <= 1'b1;
                        edge_count <= 4'd0;
                    end
                end

                CONFIG: begin
                    if (config_valid && edge_count < 4'd16) begin
                        // Update distance matrix with edge
                        if (edge_w < dist[edge_u][edge_v]) begin
                            dist[edge_u][edge_v] <= edge_w;
                            dist[edge_v][edge_u] <= edge_w;
                        end
                        edge_count <= edge_count + 4'd1;
                    end
                    if (edge_count >= 4'd16 || !config_valid) begin
                        next_state <= COMPUTE;
                        k_counter <= 3'd0;
                        i_counter <= 3'd0;
                        j_counter <= 3'd0;
                        cycle_count <= 8'd0;
                    end
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Floyd-Warshall iteration
                    if (cycle_count < MAX_CYCLES) begin
                        if (j_counter < 3'd8) begin
                            // Inner loop: j
                            if (dist[i_counter][k_counter] | dist[k_counter][j_counter] < dist[i_counter][j_counter]) begin
                                dist[i_counter][j_counter] <= dist[i_counter][k_counter] | dist[k_counter][j_counter];
                            end
                            j_counter <= j_counter + 3'd1;
                        end else begin
                            j_counter <= 3'd0;
                            if (i_counter < 3'd7) begin
                                i_counter <= i_counter + 3'd1;
                            end else begin
                                i_counter <= 3'd0;
                                if (k_counter < 3'd7) begin
                                    k_counter <= k_counter + 3'd1;
                                end else begin
                                    next_state <= QUERY;
                                end
                            end
                        end
                    end else begin
                        next_state <= QUERY;
                    end
                end

                QUERY: begin
                    result <= dist[src][dst];
                    done <= 1'b1;
                    busy <= 1'b0;
                    next_state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    next_state <= IDLE;
                    busy <= 1'b0;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule
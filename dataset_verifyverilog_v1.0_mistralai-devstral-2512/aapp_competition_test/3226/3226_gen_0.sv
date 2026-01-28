module police_escape(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] node_count,
    input wire [3:0] exit_count,
    input wire [3:0] bro_start,
    input wire [3:0] police_start,
    input wire [3:0] edge_src [0:15],
    input wire [3:0] edge_dst [0:15],
    input wire [7:0] edge_len [0:15],
    input wire [3:0] exit_list [0:7],
    output reg [15:0] result_speed,
    output reg impossible,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] INIT_FW = 4'd1;
    localparam [3:0] FW_LOOP = 4'd2;
    localparam [3:0] CHECK_EXIT = 4'd3;
    localparam [3:0] UPDATE_SPEED = 4'd4;
    localparam [3:0] DONE_STATE = 4'd5;

    // Distance matrix (8x8)
    reg [15:0] dist [0:7][0:7];
    
    // Binary search variables
    reg [15:0] speed_low;
    reg [15:0] speed_high;
    reg [15:0] speed_mid;
    
    // Loop counters
    reg [2:0] k, i, j;
    reg [2:0] exit_idx;
    reg [2:0] edge_idx;
    
    // State machine
    reg [3:0] state;
    
    // Temporary values for comparison
    reg [31:0] val_bro;
    reg [31:0] val_pol;
    
    // Constants
    localparam [15:0] POLICE_SPEED = 16'd40960; // 160.0 in Q8.8 (160 * 256)
    localparam [15:0] MAX_SPEED = 16'd65280;    // 255.0 in Q8.8 (255 * 256)
    localparam [15:0] INF = 16'd65535;
    
    // Initialize distance matrix
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_speed <= 16'd0;
            impossible <= 1'b0;
            done <= 1'b0;
            
            // Reset distance matrix
            for (i = 0; i < 8; i = i + 1) begin
                for (j = 0; j < 8; j = j + 1) begin
                    dist[i][j] <= INF;
                end
            end
            
            // Reset loop counters
            k <= 0;
            i <= 0;
            j <= 0;
            exit_idx <= 0;
            edge_idx <= 0;
            
            // Reset binary search bounds
            speed_low <= 16'd0;
            speed_high <= MAX_SPEED;
            speed_mid <= 16'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= INIT_FW;
                    end
                end
                
                INIT_FW: begin
                    // Initialize distance matrix with edge lengths
                    for (i = 0; i < 8; i = i + 1) begin
                        for (j = 0; j < 8; j = j + 1) begin
                            if (i == j) begin
                                dist[i][j] <= 16'd0;
                            end else begin
                                dist[i][j] <= INF;
                            end
                        end
                    end
                    
                    // Load edges
                    for (edge_idx = 0; edge_idx < 16; edge_idx = edge_idx + 1) begin
                        if (edge_src[edge_idx] < 8 && edge_dst[edge_idx] < 8) begin
                            dist[edge_src[edge_idx]][edge_dst[edge_idx]] <= edge_len[edge_idx];
                        end
                    end
                    
                    state <= FW_LOOP;
                    k <= 0;
                    i <= 0;
                    j <= 0;
                end
                
                FW_LOOP: begin
                    // Floyd-Warshall algorithm
                    if (k < 8) begin
                        if (i < 8) begin
                            if (j < 8) begin
                                if (dist[i][k] + dist[k][j] < dist[i][j]) begin
                                    dist[i][j] <= dist[i][k] + dist[k][j];
                                end
                                j <= j + 1;
                            end else begin
                                j <= 0;
                                i <= i + 1;
                            end
                        end else begin
                            i <= 0;
                            k <= k + 1;
                        end
                    end else begin
                        state <= CHECK_EXIT;
                        exit_idx <= 0;
                    end
                end
                
                CHECK_EXIT: begin
                    // Check if brothers can escape at current speed_mid
                    if (exit_idx < exit_count) begin
                        val_bro <= dist[bro_start][exit_list[exit_idx]] * POLICE_SPEED;
                        val_pol <= dist[police_start][exit_list[exit_idx]] * speed_mid;
                        
                        if (val_bro < val_pol && dist[police_start][exit_list[exit_idx]] != 0) begin
                            // Found a valid speed
                            result_speed <= speed_mid;
                            state <= DONE_STATE;
                        end else begin
                            exit_idx <= exit_idx + 1;
                        end
                    end else begin
                        // No valid exit found at this speed
                        state <= UPDATE_SPEED;
                    end
                end
                
                UPDATE_SPEED: begin
                    // Binary search update
                    if (speed_low >= speed_high) begin
                        // No solution found
                        impossible <= 1'b1;
                        state <= DONE_STATE;
                    end else begin
                        speed_mid <= (speed_low + speed_high) / 2;
                        
                        // Check if we need to increase or decrease speed
                        // Re-check with updated speed_mid
                        state <= CHECK_EXIT;
                        exit_idx <= 0;
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
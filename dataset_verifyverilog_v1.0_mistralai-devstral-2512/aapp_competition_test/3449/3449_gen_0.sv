module light_fence(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] B,
    input wire [2:0] H,
    input wire [3:0] grid [0:7][0:7],
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] COMPUTE = 3'd1;
    localparam [2:0] FINISH  = 3'd2;
    
    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Internal signals
    reg [15:0] total_cost;
    reg [15:0] light_level [0:7][0:7];
    reg [15:0] x, y, i, j;
    reg [15:0] dx, dy;
    reg [15:0] distance_sq;
    reg [15:0] contribution;
    reg [15:0] H_sq;
    reg [15:0] B_scaled;
    reg [15:0] temp;
    reg [15:0] edge_cost;
    reg dark [0:7][0:7];

    // Initialize H_sq and B_scaled
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            total_cost <= 16'd0;
            
            // Initialize light_level array
            for (i = 0; i < 8; i = i + 1) begin
                for (j = 0; j < 8; j = j + 1) begin
                    light_level[i][j] <= 16'd0;
                end
            end
            
            // Initialize dark array
            for (i = 0; i < 8; i = i + 1) begin
                for (j = 0; j < 8; j = j + 1) begin
                    dark[i][j] <= 1'b0;
                end
            end
            
            x <= 16'd0;
            y <= 16'd0;
            dx <= 16'd0;
            dy <= 16'd0;
            distance_sq <= 16'd0;
            contribution <= 16'd0;
            H_sq <= 16'd0;
            B_scaled <= 16'd0;
            temp <= 16'd0;
            edge_cost <= 16'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE;
                        // Precompute H_sq and B_scaled
                        H_sq <= {13'd0, H} * {13'd0, H};
                        B_scaled <= {12'd0, B} * 16'd1000;
                        x <= 16'd0;
                        y <= 16'd0;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Compute light levels for internal cells (1-6, 1-6)
                    if (x < 8 && y < 8) begin
                        if (x >= 1 && x <= 6 && y >= 1 && y <= 6) begin
                            // Reset light level for this cell
                            light_level[x][y] <= 16'd0;
                            
                            // Sum contributions from all lights
                            for (i = 0; i < 8; i = i + 1) begin
                                for (j = 0; j < 8; j = j + 1) begin
                                    dx <= (i < x) ? (x - i) : (i - x);
                                    dy <= (j < y) ? (y - j) : (j - y);
                                    distance_sq <= dx * dx + dy * dy + H_sq;
                                    
                                    if (distance_sq != 16'd0) begin
                                        contribution <= (grid[i][j] * 16'd1000) / distance_sq;
                                        light_level[x][y] <= light_level[x][y] + contribution;
                                    end
                                end
                            end
                            
                            // Check if cell is dark
                            dark[x][y] <= (light_level[x][y] < B_scaled);
                        end
                        
                        // Move to next cell
                        x <= x + 16'd1;
                        if (x == 8) begin
                            x <= 16'd0;
                            y <= y + 16'd1;
                        end
                    end else begin
                        // Calculate fencing cost
                        total_cost <= 16'd0;
                        
                        // Check horizontal edges (between columns)
                        for (i = 1; i <= 6; i = i + 1) begin
                            for (j = 0; j <= 6; j = j + 1) begin
                                edge_cost <= (dark[i][j] || dark[i][j+1]) ? 16'd11 : 16'd43;
                                total_cost <= total_cost + edge_cost;
                            end
                        end
                        
                        // Check vertical edges (between rows)
                        for (i = 0; i <= 6; i = i + 1) begin
                            for (j = 1; j <= 6; j = j + 1) begin
                                edge_cost <= (dark[i][j] || dark[i+1][j]) ? 16'd11 : 16'd43;
                                total_cost <= total_cost + edge_cost;
                            end
                        end
                        
                        state <= FINISH;
                    end
                    
                    // Exit conditions
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    result <= total_cost;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule
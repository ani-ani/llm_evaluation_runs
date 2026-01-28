module GarlandComplexityMinimizer(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [6:0] n,
    input wire [99:0] arr_parity,
    input wire [5:0] odd_total,
    input wire [5:0] even_total,
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] INIT = 2'd1;
    localparam [1:0] COMPUTE = 2'd2;
    localparam [1:0] FINISH = 2'd3;
    
    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    // DP state registers
    reg [5:0] state_odd_used;
    reg [0:0] state_prev_par;
    reg [7:0] current_cost;

    // DP table (16x16x2)
    reg [7:0] dp_current [0:15][0:15][0:1];
    reg [7:0] dp_next [0:15][0:15][0:1];

    // Position counter
    reg [3:0] position;

    // Intermediate signals
    reg [7:0] min_cost;
    reg [7:0] temp_cost;
    reg [5:0] temp_odd_used;
    reg [0:0] temp_prev_par;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            position <= 4'd0;
            state_odd_used <= 6'd0;
            state_prev_par <= 1'b0;
            current_cost <= 8'd0;
            
            // Initialize DP tables
            integer i, j, k;
            for (i = 0; i < 16; i = i + 1) begin
                for (j = 0; j < 16; j = j + 1) begin
                    for (k = 0; k < 2; k = k + 1) begin
                        dp_current[i][j][k] <= 8'd255;
                        dp_next[i][j][k] <= 8'd255;
                    end
                end
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= INIT;
                    end
                end
                
                INIT: begin
                    // Initialize DP[0][0][0] and DP[0][0][1]
                    dp_current[0][0][0] <= 8'd0;
                    dp_current[0][0][1] <= 8'd0;
                    
                    // Reset position counter
                    position <= 4'd0;
                    state <= COMPUTE;
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check if we've processed all positions
                    if (position == n[3:0]) begin
                        state <= FINISH;
                    end else begin
                        // Process current position
                        integer i, j, k;
                        
                        // Initialize next DP table
                        for (i = 0; i < 16; i = i + 1) begin
                            for (j = 0; j < 16; j = j + 1) begin
                                for (k = 0; k < 2; k = k + 1) begin
                                    dp_next[i][j][k] <= 8'd255;
                                end
                            end
                        end
                        
                        // Process each state
                        for (i = 0; i < 16; i = i + 1) begin
                            for (j = 0; j < 16; j = j + 1) begin
                                for (k = 0; k < 2; k = k + 1) begin
                                    if (dp_current[i][j][k] != 8'd255) begin
                                        // Check if current position is fixed or zero
                                        if (arr_parity[position]) begin
                                            // Fixed number - use its parity
                                            temp_cost = dp_current[i][j][k] + (k != arr_parity[position] ? 8'd1 : 8'd0);
                                            temp_odd_used = i;
                                            temp_prev_par = arr_parity[position];
                                            
                                            // Update next state if better
                                            if (temp_cost < dp_next[temp_odd_used][temp_prev_par][temp_prev_par]) begin
                                                dp_next[temp_odd_used][temp_prev_par][temp_prev_par] <= temp_cost;
                                            end
                                        end else begin
                                            // Zero position - try both odd and even
                                            // Try placing odd (if available)
                                            if (i < odd_total) begin
                                                temp_cost = dp_current[i][j][k] + (k != 1'b1 ? 8'd1 : 8'd0);
                                                temp_odd_used = i + 6'd1;
                                                temp_prev_par = 1'b1;
                                                
                                                if (temp_cost < dp_next[temp_odd_used][temp_prev_par][temp_prev_par]) begin
                                                    dp_next[temp_odd_used][temp_prev_par][temp_prev_par] <= temp_cost;
                                                end
                                            end
                                            
                                            // Try placing even (if available)
                                            if ((16 - i) < even_total) begin
                                                temp_cost = dp_current[i][j][k] + (k != 1'b0 ? 8'd1 : 8'd0);
                                                temp_odd_used = i;
                                                temp_prev_par = 1'b0;
                                                
                                                if (temp_cost < dp_next[temp_odd_used][temp_prev_par][temp_prev_par]) begin
                                                    dp_next[temp_odd_used][temp_prev_par][temp_prev_par] <= temp_cost;
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                        
                        // Copy next to current
                        for (i = 0; i < 16; i = i + 1) begin
                            for (j = 0; j < 16; j = j + 1) begin
                                for (k = 0; k < 2; k = k + 1) begin
                                    dp_current[i][j][k] <= dp_next[i][j][k];
                                end
                            end
                        end
                        
                        // Increment position
                        position <= position + 4'd1;
                    end
                    
                    // Safety check for max cycles
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    // Find minimum cost in final states
                    min_cost = dp_current[odd_total][0][0];
                    if (dp_current[odd_total][1][1] < min_cost) begin
                        min_cost = dp_current[odd_total][1][1];
                    end
                    
                    result <= {8'd0, min_cost};
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule
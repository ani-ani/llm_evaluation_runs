module nudgemon_go (
    input clk,
    input rst_n,
    input start,
    input [3:0] family_sizes,
    input [31:0] evolution_costs,
    input [31:0] catch_times,
    input [15:0] catch_names,
    output reg [15:0] max_xp,
    output reg done
);
    
    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] PARSE_FAMILIES = 3'd1;
    localparam [2:0] PARSE_CATCHES = 3'd2;
    localparam [2:0] COMPUTE_WINDOWS = 3'd3;
    localparam [2:0] OUTPUT = 3'd4;
    
    // Constants
    localparam [7:0] NUM_FAMILIES = 8'd4;
    localparam [7:0] MAX_CATCHES = 8'd16;
    localparam [7:0] WINDOW_SIZE = 8'd16;
    
    // State registers
    reg [2:0] state;
    reg [7:0] timer;
    reg [7:0] window_start;
    reg [15:0] current_xp;
    reg [15:0] best_xp_reg;
    reg [7:0] best_start;
    
    // Family data storage
    reg [7:0] family_kinds [0:3];
    reg [7:0] family_costs [0:15];
    
    // Catch data storage
    reg [7:0] catch_time [0:15];
    reg [3:0] catch_family [0:15];
    reg [3:0] catch_type [0:15];
    
    // Working registers
    reg [7:0] candy [0:3];
    reg [7:0] mon_count [0:15];
    reg [7:0] i, j, k;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            max_xp <= 16'd0;
            timer <= 8'd0;
            
            // Initialize all registers
            for (i = 0; i < 4; i = i + 1) begin
                family_kinds[i] <= 8'd0;
                candy[i] <= 8'd0;
            end
            
            for (i = 0; i < 16; i = i + 1) begin
                family_costs[i] <= 8'd0;
                catch_time[i] <= 8'd0;
                catch_family[i] <= 4'd0;
                catch_type[i] <= 4'd0;
                mon_count[i] <= 8'd0;
            end
            
            best_xp_reg <= 16'd0;
            best_start <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= PARSE_FAMILIES;
                        timer <= 8'd0;
                    end
                end
                
                PARSE_FAMILIES: begin
                    if (timer < NUM_FAMILIES) begin
                        family_kinds[timer] <= family_sizes[timer*8 +: 8];
                        
                        // Extract costs for this family
                        for (i = 0; i < 4; i = i + 1) begin
                            family_costs[timer*4 + i] <= evolution_costs[(timer*4 + i)*8 +: 8];
                        end
                        
                        timer <= timer + 8'd1;
                    end else begin
                        state <= PARSE_CATCHES;
                        timer <= 8'd0;
                    end
                end
                
                PARSE_CATCHES: begin
                    if (timer < MAX_CATCHES) begin
                        catch_time[timer] <= catch_times[timer*8 +: 8];
                        catch_family[timer] <= catch_names[timer*4 +: 2];
                        catch_type[timer] <= catch_names[timer*4 + 2 +: 2];
                        
                        timer <= timer + 8'd1;
                    end else begin
                        state <= COMPUTE_WINDOWS;
                        window_start <= 8'd0;
                        best_xp_reg <= 16'd0;
                        best_start <= 8'd0;
                    end
                end
                
                COMPUTE_WINDOWS: begin
                    // Reset counters for new window
                    for (i = 0; i < 4; i = i + 1) begin
                        candy[i] <= 8'd0;
                    end
                    
                    for (i = 0; i < 16; i = i + 1) begin
                        mon_count[i] <= 8'd0;
                    end
                    
                    // Count catches in current window
                    for (i = 0; i < MAX_CATCHES; i = i + 1) begin
                        if (catch_time[i] >= window_start && catch_time[i] < window_start + WINDOW_SIZE) begin
                            // Increment mon count
                            mon_count[catch_family[i]*4 + catch_type[i]] <= 
                                mon_count[catch_family[i]*4 + catch_type[i]] + 8'd1;
                        end
                    end
                    
                    // Calculate candy from mon counts
                    for (i = 0; i < 4; i = i + 1) begin
                        for (j = 0; j < 4; j = j + 1) begin
                            k <= i*4 + j;
                            if (mon_count[k] >= 8'd3) begin
                                candy[i] <= candy[i] + (mon_count[k] / 8'd3);
                            end
                        end
                    end
                    
                    // Calculate XP from evolutions
                    current_xp <= 16'd0;
                    for (i = 0; i < 4; i = i + 1) begin
                        for (j = 0; j < 4; j = j + 1) begin
                            k <= i*4 + j;
                            if (j < family_kinds[i] && candy[i] >= family_costs[k]) begin
                                current_xp <= current_xp + 16'd100;
                                candy[i] <= candy[i] - family_costs[k];
                            end
                        end
                    end
                    
                    // Update best XP
                    if (current_xp > best_xp_reg) begin
                        best_xp_reg <= current_xp;
                        best_start <= window_start;
                    end
                    
                    // Move to next window
                    window_start <= window_start + 8'd1;
                    
                    // Check if we've processed all possible windows
                    if (window_start + WINDOW_SIZE > 8'd255) begin
                        state <= OUTPUT;
                    end
                end
                
                OUTPUT: begin
                    max_xp <= best_xp_reg;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end
endmodule
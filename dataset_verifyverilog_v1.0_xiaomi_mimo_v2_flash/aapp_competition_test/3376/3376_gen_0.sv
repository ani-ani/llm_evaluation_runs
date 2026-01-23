module nudgemon_go (
    input clk,
    input rst_n,
    input start,
    input [15:0] family_sizes,
    input [31:0] evolution_costs,
    input [31:0] catch_times,
    input [15:0] catch_names,
    output reg [15:0] max_xp,
    output reg done
);
    // State machine states
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] PARSE = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] OUTPUT = 3'd3;
    
    reg [2:0] state;
    reg [7:0] timer;
    reg [7:0] window_start;
    reg [15:0] current_xp;
    reg [7:0] best_start;
    
    // Storage for parsed data
    reg [3:0] family_kinds [0:3];
    reg [7:0] costs [0:3];
    reg [7:0] catch_time [0:3];
    reg [3:0] catch_family [0:3];
    reg [3:0] catch_type [0:3];
    
    // Counters for window evaluation
    reg [7:0] candy [0:3];
    reg [15:0] mon_count;
    reg [7:0] window_candy [0:3];
    
    // Parameters
    localparam [7:0] MAX_CATCHES = 8'd4;
    localparam [7:0] MAX_FAMILIES = 8'd4;
    localparam [7:0] WINDOW_DUR = 8'd16;
    localparam [7:0] MAX_TIME = 8'd255;
    
    integer i, j;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            max_xp <= 16'd0;
            timer <= 8'd0;
            window_start <= 8'd0;
            current_xp <= 16'd0;
            best_start <= 8'd0;
            mon_count <= 16'd0;
            for (i = 0; i < 4; i = i + 1) begin
                family_kinds[i] <= 4'd0;
                costs[i] <= 8'd0;
                catch_time[i] <= 8'd0;
                catch_family[i] <= 4'd0;
                catch_type[i] <= 4'd0;
                candy[i] <= 8'd0;
                window_candy[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= PARSE;
                        timer <= 8'd0;
                    end
                end
                
                PARSE: begin
                    if (timer < MAX_FAMILIES) begin
                        family_kinds[timer] <= family_sizes[timer*4 +: 4];
                        costs[timer] <= evolution_costs[timer*8 +: 8];
                        timer <= timer + 8'd1;
                    end else if (timer < MAX_FAMILIES + MAX_CATCHES) begin
                        j = timer - MAX_FAMILIES;
                        catch_time[j] <= catch_times[j*8 +: 8];
                        catch_family[j] <= catch_names[j*4 +: 2];
                        catch_type[j] <= catch_names[j*4 + 2 +: 2];
                        timer <= timer + 8'd1;
                    end else begin
                        state <= COMPUTE;
                        window_start <= 8'd0;
                        current_xp <= 16'd0;
                    end
                end
                
                COMPUTE: begin
                    if (window_start <= 8'd239) begin
                        // Reset window counters
                        for (i = 0; i < 4; i = i + 1) begin
                            window_candy[i] <= 8'd0;
                            candy[i] <= 8'd0;
                        end
                        mon_count <= 16'd0;
                        
                        // Count catches in window
                        for (i = 0; i < 4; i = i + 1) begin
                            if (catch_time[i] >= window_start && catch_time[i] < window_start + WINDOW_DUR) begin
                                window_candy[catch_family[i]] <= window_candy[catch_family[i]] + 8'd1;
                                mon_count <= mon_count + 8'd1;
                            end
                        end
                        
                        // Greedy evolution
                        current_xp <= 16'd0;
                        for (i = 0; i < 4; i = i + 1) begin
                            if (candy[i] < 8'd100) begin
                                candy[i] <= candy[i] + window_candy[i];
                            end
                        end
                        
                        // Compute XP from evolutions
                        for (i = 0; i < 4; i = i + 1) begin
                            if (candy[i] >= 8'd12) begin
                                current_xp <= current_xp + costs[i] * (candy[i] / 8'd12);
                            end
                        end
                        
                        // Update best
                        if (current_xp > max_xp) begin
                            max_xp <= current_xp;
                            best_start <= window_start;
                        end
                        
                        window_start <= window_start + 8'd1;
                    end else begin
                        state <= OUTPUT;
                    end
                end
                
                OUTPUT: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule
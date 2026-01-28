module PermutationCounter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [2:0] m,
    input wire [15:0] obs_switch [0:7],
    input wire [15:0] obs_light [0:7],
    output reg [23:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE = 3'd1;
    localparam [2:0] FINISH = 3'd2;
    
    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd1000;

    // DP state variables
    reg [3:0] current_switch;
    reg [15:0] used_mask;
    reg [23:0] dp_current;
    reg [23:0] dp_next;
    reg [23:0] dp_table [0:15][0:65535];

    // Observation consistency check
    reg [15:0] consistent_lights;
    integer j, k;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 24'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            current_switch <= 4'd0;
            used_mask <= 16'd0;
            dp_current <= 24'd0;
            dp_next <= 24'd0;
            
            // Initialize DP table
            for (j = 0; j < 16; j = j + 1) begin
                for (k = 0; k < 65536; k = k + 1) begin
                    dp_table[j][k] <= 24'd0;
                end
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE;
                        current_switch <= 4'd0;
                        used_mask <= 16'd0;
                        dp_current <= 24'd1;  // Base case: 1 way to have 0 switches
                        dp_table[0][0] <= 24'd1;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check if we've processed all switches
                    if (current_switch == n) begin
                        state <= FINISH;
                        result <= dp_current;
                    end else begin
                        // Compute consistent lights for current switch
                        consistent_lights <= 16'd0;
                        for (j = 0; j < m; j = j + 1) begin
                            if (obs_switch[j][current_switch]) begin
                                // Light must be 1 in this observation
                                for (k = 0; k < n; k = k + 1) begin
                                    if (obs_light[j][k]) begin
                                        consistent_lights[k] <= 1'b1;
                                    end
                                end
                            end else begin
                                // Light must be 0 in this observation
                                for (k = 0; k < n; k = k + 1) begin
                                    if (!obs_light[j][k]) begin
                                        consistent_lights[k] <= 1'b1;
                                    end
                                end
                            end
                        end
                        
                        // Try all unused lights that are consistent
                        dp_next <= 24'd0;
                        for (k = 0; k < n; k = k + 1) begin
                            if (!used_mask[k] && consistent_lights[k]) begin
                                dp_next <= (dp_next + dp_table[current_switch][used_mask]) % 24'd1000003;
                            end
                        end
                        
                        // Update DP table for next state
                        dp_table[current_switch + 1][used_mask | (1 << k)] <= dp_next;
                        
                        // Move to next switch
                        current_switch <= current_switch + 4'd1;
                    end
                    
                    // Safety check for cycle limit
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                        result <= dp_current;
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
    
    // Helper function for modulo operation
    function [23:0] mod_1000003;
        input [23:0] value;
        begin
            if (value >= 24'd1000003) begin
                mod_1000003 = value - 24'd1000003;
            end else begin
                mod_1000003 = value;
            end
        end
    endfunction

endmodule
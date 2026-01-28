module gem_collection(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] gem_x_in,
    input wire [7:0] gem_y_in,
    input wire [3:0] gem_idx_in,
    input wire [3:0] num_gems,
    input wire [3:0] r_in,
    input wire [7:0] w_in,
    output reg [7:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] LOAD      = 3'd1;
    localparam [2:0] CALCULATE = 3'd2;
    localparam [2:0] DONE_STATE = 3'd3;

    reg [2:0] state, next_state;

    // Internal registers
    reg [3:0] i_reg, j_reg;
    reg [3:0] max_gems;
    reg [3:0] dp [0:15];
    reg [7:0] x_ram [0:15];
    reg [7:0] y_ram [0:15];
    reg [3:0] r_reg;
    reg [7:0] w_reg;
    reg [3:0] num_gems_reg;

    // Intermediate calculations
    reg [7:0] dx, dy;
    reg [15:0] dx_times_r;
    reg reachable;

    // Cycle counter to prevent infinite loops
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            i_reg <= 4'd0;
            j_reg <= 4'd0;
            max_gems <= 4'd0;
            r_reg <= 4'd0;
            w_reg <= 8'd0;
            num_gems_reg <= 4'd0;
            
            // Initialize arrays
            integer k;
            for (k = 0; k < 16; k = k + 1) begin
                x_ram[k] <= 8'd0;
                y_ram[k] <= 8'd0;
                dp[k] <= 4'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= LOAD;
                        i_reg <= 4'd0;
                        r_reg <= r_in;
                        w_reg <= w_in;
                        num_gems_reg <= num_gems;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                LOAD: begin
                    if (gem_idx_in < num_gems_reg) begin
                        x_ram[gem_idx_in] <= gem_x_in;
                        y_ram[gem_idx_in] <= gem_y_in;
                        if (gem_idx_in == num_gems_reg - 1) begin
                            next_state <= CALCULATE;
                            i_reg <= 4'd0;
                            j_reg <= 4'd0;
                            max_gems <= 4'd0;
                            
                            // Initialize dp array
                            integer k;
                            for (k = 0; k < 16; k = k + 1) begin
                                dp[k] <= 4'd1;
                            end
                        end else begin
                            next_state <= LOAD;
                        end
                    end else begin
                        next_state <= CALCULATE;
                        i_reg <= 4'd0;
                        j_reg <= 4'd0;
                        max_gems <= 4'd0;
                        
                        // Initialize dp array
                        integer k;
                        for (k = 0; k < 16; k = k + 1) begin
                            dp[k] <= 4'd1;
                        end
                    end
                end

                CALCULATE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Outer loop: i from 0 to N-1
                    if (i_reg < num_gems_reg) begin
                        // Inner loop: j from 0 to i-1
                        if (j_reg < i_reg) begin
                            // Compute dy = y_ram[i] - y_ram[j]
                            if (y_ram[i_reg] >= y_ram[j_reg]) begin
                                dy <= y_ram[i_reg] - y_ram[j_reg];
                                
                                // Compute dx = abs(x_ram[i] - x_ram[j])
                                if (x_ram[i_reg] >= x_ram[j_reg]) begin
                                    dx <= x_ram[i_reg] - x_ram[j_reg];
                                end else begin
                                    dx <= x_ram[j_reg] - x_ram[i_reg];
                                end
                                
                                // Compute dx * r
                                dx_times_r <= dx * r_reg;
                                
                                // Check reachability: dx * r <= dy
                                if (dx_times_r <= dy) begin
                                    reachable <= 1'b1;
                                    
                                    // Check bounds (0 <= x <= w)
                                    if (x_ram[i_reg] >= 8'd0 && x_ram[i_reg] <= w_reg) begin
                                        if (dp[j_reg] + 4'd1 > dp[i_reg]) begin
                                            dp[i_reg] <= dp[j_reg] + 4'd1;
                                        end
                                    end
                                end else begin
                                    reachable <= 1'b0;
                                end
                                
                                j_reg <= j_reg + 4'd1;
                            end else begin
                                j_reg <= j_reg + 4'd1;
                            end
                        end else begin
                            // Update max_gems
                            if (dp[i_reg] > max_gems) begin
                                max_gems <= dp[i_reg];
                            end
                            
                            i_reg <= i_reg + 4'd1;
                            j_reg <= 4'd0;
                        end
                    end else begin
                        next_state <= DONE_STATE;
                    end
                    
                    // Safety: prevent infinite loops
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    result <= max_gems;
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule
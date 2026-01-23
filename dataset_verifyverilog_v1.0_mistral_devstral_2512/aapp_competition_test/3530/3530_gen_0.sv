module roller_coaster_optimization(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [1:0] N,
    input wire [31:0] coeff0,
    input wire [31:0] coeff1,
    input wire [31:0] coeff2,
    input wire [31:0] coeff3,
    input wire [6:0] T,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] FINISH = 3'd3;
    
    reg [2:0] state, next_state;
    
    // Coefficient storage
    reg [11:0] a [0:3];
    reg [11:0] b [0:3];
    reg [7:0] t [0:3];
    
    // DP array (128 entries for time 0-127)
    reg [15:0] dp [0:127];
    
    // Control signals
    reg [1:0] current_coaster;
    reg [4:0] current_k;
    reg [6:0] current_time;
    reg [15:0] current_fun;
    reg [6:0] time_needed;
    reg [15:0] temp_dp;
    
    // Cycle counter for timeout
    reg [12:0] cycle_count;
    localparam [12:0] MAX_CYCLES = 13'd4999;
    
    // Load coefficients
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 16'd0;
            current_coaster <= 2'd0;
            current_k <= 5'd0;
            current_time <= 7'd0;
            cycle_count <= 13'd0;
            
            // Initialize DP array
            integer i;
            for (i = 0; i < 128; i = i + 1) begin
                dp[i] <= 16'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 13'd0;
                    if (start) begin
                        next_state <= LOAD;
                    end else begin
                        next_state <= IDLE;
                    end
                end
                
                LOAD: begin
                    // Load coefficients
                    a[0] <= coeff0[23:12];
                    b[0] <= coeff0[11:0];
                    t[0] <= coeff0[7:0];
                    
                    a[1] <= coeff1[23:12];
                    b[1] <= coeff1[11:0];
                    t[1] <= coeff1[7:0];
                    
                    a[2] <= coeff2[23:12];
                    b[2] <= coeff2[11:0];
                    t[2] <= coeff2[7:0];
                    
                    a[3] <= coeff3[23:12];
                    b[3] <= coeff3[11:0];
                    t[3] <= coeff3[7:0];
                    
                    current_coaster <= 2'd0;
                    next_state <= COMPUTE;
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 13'd1;
                    
                    // Process current coaster
                    if (current_coaster < N) begin
                        // Try different k values
                        if (current_k < 5'd31) begin
                            // Calculate fun = a - (k-1)^2 * b
                            current_fun <= a[current_coaster] - ((current_k - 5'd1) * (current_k - 5'd1)) * b[current_coaster];
                            
                            // Calculate time needed
                            time_needed <= current_k * t[current_coaster];
                            
                            // Update DP array if conditions met
                            if (current_fun > 16'd0 && time_needed <= 7'd127) begin
                                current_time <= time_needed;
                                if (current_time <= 7'd127) begin
                                    temp_dp <= dp[current_time - time_needed] + current_fun;
                                    if (temp_dp > dp[current_time]) begin
                                        dp[current_time] <= temp_dp;
                                    end
                                end
                            end
                            
                            current_k <= current_k + 5'd1;
                        end else begin
                            // Move to next coaster
                            current_k <= 5'd0;
                            current_coaster <= current_coaster + 2'd1;
                        end
                    end else begin
                        // All coasters processed
                        next_state <= FINISH;
                    end
                    
                    // Timeout check
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= FINISH;
                    end
                end
                
                FINISH: begin
                    result <= dp[T];
                    done <= 1'b1;
                    next_state <= IDLE;
                end
                
                default: next_state <= IDLE;
            endcase
        end
    end
    
    // Default state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            next_state <= IDLE;
        end
    end

endmodule
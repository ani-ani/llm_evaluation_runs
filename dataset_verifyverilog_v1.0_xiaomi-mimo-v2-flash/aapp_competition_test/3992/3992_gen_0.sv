module chocolate_box_problem(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr [0:15],
    input wire [3:0] len,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [3:0] IDLE          = 4'd0;
    localparam [3:0] CALC_SUM      = 4'd1;
    localparam [3:0] CHECK_SUM     = 4'd2;
    localparam [3:0] FIND_FACTORS  = 4'd3;
    localparam [3:0] CHECK_FACTORS = 4'd4;
    localparam [3:0] CALC_DIV      = 4'd5;
    localparam [3:0] CALC_COST     = 4'd6;
    localparam [3:0] UPDATE_MIN    = 4'd7;
    localparam [3:0] NEXT_DIV      = 4'd8;
    localparam [3:0] FINISH        = 4'd9;
    localparam [3:0] ERROR         = 4'd10;

    reg [3:0] state;
    reg [3:0] next_state;
    
    // Registers
    reg [23:0] sum;           // Total sum (max 4080)
    reg [3:0] idx;            // General index (0-15)
    reg [3:0] i;              // Loop counter
    reg [7:0] divisor;        // Candidate divisor k (1-255)
    reg [23:0] temp_sum;      // Temporary sum for trial division
    reg [7:0] factor_count;   // Number of factors found
    reg [7:0] current_k;      // Current divisor being evaluated
    reg [7:0] k_idx;          // Index for factor array
    reg [15:0] min_cost;      // Minimum cost found
    reg [15:0] current_cost;  // Cost for current divisor
    reg [15:0] running_remainder; // Remainder accumulator
    reg [7:0] temp_r;         // Temporary remainder
    reg [7:0] k_half;         // k/2 for comparison
    
    // Factor storage (max 8 factors, 8-bit each)
    reg [7:0] factors [0:7];
    
    // Cycle counter for timeout
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Function to extract prime factors
    task find_factors;
        input [23:0] s;
        begin
            factor_count = 8'd0;
            temp_sum = s;
            
            // Check factor 2
            while (temp_sum[0] == 1'b0 && temp_sum > 24'd0 && factor_count < 8'd8) begin
                factors[factor_count] = 8'd2;
                factor_count = factor_count + 8'd1;
                temp_sum = temp_sum >> 1;
            end
            
            // Check odd factors up to 255
            for (i = 3; i <= 255 && i * i <= temp_sum && temp_sum > 24'd1; i = i + 2) begin
                if (temp_sum % i == 24'd0 && factor_count < 8'd8) begin
                    factors[factor_count] = i[7:0];
                    factor_count = factor_count + 8'd1;
                    while (temp_sum % i == 24'd0 && temp_sum > 24'd1) begin
                        temp_sum = temp_sum / i;
                    end
                end
            end
            
            // If remaining temp_sum is prime and > 255, don't add (out of range)
            // If remaining temp_sum is > 1 and < 256, add it
            if (temp_sum > 24'd1 && temp_sum < 24'd256 && factor_count < 8'd8) begin
                factors[factor_count] = temp_sum[7:0];
                factor_count = factor_count + 8'd1;
            end
        end
    endtask

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            sum <= 24'd0;
            idx <= 4'd0;
            i <= 4'd0;
            divisor <= 8'd0;
            factor_count <= 8'd0;
            current_k <= 8'd0;
            k_idx <= 8'd0;
            min_cost <= 16'hFFFF;
            current_cost <= 16'd0;
            running_remainder <= 16'd0;
            temp_r <= 8'd0;
            k_half <= 8'd0;
            temp_sum <= 24'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    sum <= 24'd0;
                    idx <= 4'd0;
                    i <= 4'd0;
                    divisor <= 8'd0;
                    factor_count <= 8'd0;
                    current_k <= 8'd0;
                    k_idx <= 8'd0;
                    min_cost <= 16'hFFFF;
                    current_cost <= 16'd0;
                    running_remainder <= 16'd0;
                    temp_r <= 8'd0;
                    k_half <= 8'd0;
                    temp_sum <= 24'd0;
                    if (start) begin
                        state <= CALC_SUM;
                        idx <= 4'd0;
                    end
                end
                
                CALC_SUM: begin
                    if (idx < len) begin
                        sum <= sum + {16'd0, arr[idx]};
                        idx <= idx + 4'd1;
                    end else begin
                        state <= CHECK_SUM;
                        idx <= 4'd0;
                    end
                end
                
                CHECK_SUM: begin
                    if (sum <= 24'd1) begin
                        state <= ERROR;
                    end else begin
                        state <= FIND_FACTORS;
                    end
                end
                
                FIND_FACTORS: begin
                    find_factors(sum);
                    state <= CHECK_FACTORS;
                end
                
                CHECK_FACTORS: begin
                    if (factor_count == 8'd0) begin
                        state <= ERROR;
                    end else begin
                        k_idx <= 8'd0;
                        min_cost <= 16'hFFFF;
                        state <= CALC_DIV;
                    end
                end
                
                CALC_DIV: begin
                    if (k_idx < factor_count) begin
                        current_k <= factors[k_idx];
                        k_half <= factors[k_idx] >> 1;
                        current_cost <= 16'd0;
                        running_remainder <= 16'd0;
                        idx <= 4'd0;
                        state <= CALC_COST;
                    end else begin
                        state <= FINISH;
                    end
                end
                
                CALC_COST: begin
                    if (idx < len) begin
                        temp_r <= (running_remainder + {16'd0, arr[idx]}) % current_k;
                        state <= UPDATE_MIN;
                    end else begin
                        // Update min cost after finishing current divisor
                        if (current_cost < min_cost) begin
                            min_cost <= current_cost;
                        end
                        state <= NEXT_DIV;
                    end
                end
                
                UPDATE_MIN: begin
                    // Add to cost based on remainder comparison
                    if (temp_r <= k_half) begin
                        current_cost <= current_cost + {8'd0, temp_r};
                        running_remainder <= temp_r;
                    end else begin
                        current_cost <= current_cost + (current_k - temp_r);
                        running_remainder <= (current_k - temp_r) % current_k;
                    end
                    idx <= idx + 4'd1;
                    state <= CALC_COST;
                end
                
                NEXT_DIV: begin
                    k_idx <= k_idx + 8'd1;
                    state <= CALC_DIV;
                end
                
                FINISH: begin
                    if (min_cost == 16'hFFFF) begin
                        result <= 16'hFFFF;  // -1
                    end else begin
                        result <= min_cost;
                    end
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                ERROR: begin
                    result <= 16'hFFFF;  // -1
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
            
            // Cycle counter (safety)
            if (state != IDLE) begin
                cycle_count <= cycle_count + 8'd1;
            end
            
            // Timeout check
            if (cycle_count >= MAX_CYCLES && state != IDLE && state != FINISH && state != ERROR) begin
                state <= ERROR;
            end
        end
    end

endmodule
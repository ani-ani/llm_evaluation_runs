module roller_coaster_optimization(
    input clk,
    input rst_n,
    input start,
    input [1:0] N,
    input [31:0] coeff0,
    input [31:0] coeff1,
    input [31:0] coeff2,
    input [31:0] coeff3,
    input [6:0] T,
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE        = 3'd0;
    localparam [2:0] LOAD_COEFF  = 3'd1;
    localparam [2:0] RESET_DP    = 3'd2;
    localparam [2:0] PROCESS     = 3'd3;
    localparam [2:0] COMPUTE_RIDES = 3'd4;
    localparam [2:0] UPDATE_DP   = 3'd5;
    localparam [2:0] FINISH      = 3'd6;

    // Coefficient field offsets
    localparam [3:0] A_OFFSET = 4'd20;  // {a[11:0], b[11:0], t[7:0]}
    localparam [3:0] B_OFFSET = 4'd8;
    localparam [3:0] T_OFFSET = 4'd0;

    localparam [6:0] MAX_TIME = 7'd127;
    localparam [4:0] MAX_RIDES = 5'd31;
    localparam [4:0] MAX_COASTERS = 4'd4;

    reg [2:0] state, next_state;
    reg [4:0] coaster_idx, next_coaster_idx;
    reg [4:0] ride_count, next_ride_count;
    reg [6:0] dp_index, next_dp_index;
    reg [6:0] dp_write_index, next_dp_write_index;
    
    // Coefficient storage
    reg [11:0] a_reg [0:3];
    reg [11:0] b_reg [0:3];
    reg [7:0] t_reg [0:3];
    
    // DP array - 128 entries of 16 bits
    reg [15:0] dp_reg [0:127];
    
    // Computation registers
    reg [15:0] current_fun, next_current_fun;
    reg [15:0] current_dp, next_current_dp;
    reg [15:0] candidate_dp, next_candidate_dp;
    reg [15:0] best_fun, next_best_fun;
    reg [7:0] time_needed, next_time_needed;
    reg [4:0] k, next_k;  // ride count for current coaster
    reg [2:0] current_coaster, next_current_coaster;
    
    // Cycle counter for timeout prevention
    reg [12:0] cycle_count, next_cycle_count;
    localparam [12:0] MAX_CYCLES = 13'd5000;
    
    // Helper variables for loops (must be declared outside always blocks)
    integer i;

    // State transition and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            coaster_idx <= 5'd0;
            ride_count <= 5'd0;
            dp_index <= 7'd0;
            dp_write_index <= 7'd0;
            current_fun <= 16'd0;
            current_dp <= 16'd0;
            candidate_dp <= 16'd0;
            best_fun <= 16'd0;
            time_needed <= 8'd0;
            k <= 5'd0;
            current_coaster <= 3'd0;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 13'd0;
            
            // Reset coefficient arrays
            for (i = 0; i < 4; i = i + 1) begin
                a_reg[i] <= 12'd0;
                b_reg[i] <= 12'd0;
                t_reg[i] <= 8'd0;
            end
            
            // Reset DP array
            for (i = 0; i < 128; i = i + 1) begin
                dp_reg[i] <= 16'd0;
            end
        end else begin
            state <= next_state;
            coaster_idx <= next_coaster_idx;
            ride_count <= next_ride_count;
            dp_index <= next_dp_index;
            dp_write_index <= next_dp_write_index;
            current_fun <= next_current_fun;
            current_dp <= next_current_dp;
            candidate_dp <= next_candidate_dp;
            best_fun <= next_best_fun;
            time_needed <= next_time_needed;
            k <= next_k;
            current_coaster <= next_current_coaster;
            cycle_count <= next_cycle_count;
            
            if (state == FINISH) begin
                result <= dp_reg[T];
                done <= 1'b1;
            end else begin
                done <= 1'b0;
            end
            
            // Update DP array in UPDATE_DP state
            if (state == UPDATE_DP) begin
                if (candidate_dp > current_dp) begin
                    dp_reg[dp_write_index] <= candidate_dp;
                end
            end
            
            // Load coefficients
            if (state == LOAD_COEFF) begin
                case (coaster_idx)
                    0: begin
                        a_reg[0] <= coeff0[31:20];
                        b_reg[0] <= coeff0[19:8];
                        t_reg[0] <= coeff0[7:0];
                    end
                    1: begin
                        a_reg[1] <= coeff1[31:20];
                        b_reg[1] <= coeff1[19:8];
                        t_reg[1] <= coeff1[7:0];
                    end
                    2: begin
                        a_reg[2] <= coeff2[31:20];
                        b_reg[2] <= coeff2[19:8];
                        t_reg[2] <= coeff2[7:0];
                    end
                    3: begin
                        a_reg[3] <= coeff3[31:20];
                        b_reg[3] <= coeff3[19:8];
                        t_reg[3] <= coeff3[7:0];
                    end
                    default: begin
                        a_reg[0] <= 12'd0;
                        b_reg[0] <= 12'd0;
                        t_reg[0] <= 8'd0;
                    end
                endcase
            end
            
            // Reset DP array entries
            if (state == RESET_DP) begin
                dp_reg[dp_index] <= 16'd0;
            end
            
            // Compute current DP value and best function value
            if (state == COMPUTE_RIDES) begin
                // Calculate fun = a - (k-1)^2 * b
                // Using 16-bit signed arithmetic
                begin : compute_fun_block
                    reg signed [15:0] k_minus_1;
                    reg signed [31:0] k_squared;
                    reg signed [31:0] b_times_ksq;
                    reg signed [31:0] a_signed;
                    reg signed [31:0] fun_calc;
                    
                    k_minus_1 = k - 1;
                    k_squared = k_minus_1 * k_minus_1;
                    a_signed = {4'd0, a_reg[current_coaster]};
                    b_times_ksq = b_reg[current_coaster] * k_squared[15:0];
                    fun_calc = a_signed - b_times_ksq;
                    
                    if (fun_calc[31:15] != 17'h00000 && fun_calc[31:15] != 17'h1FFFF) begin
                        // Overflow or negative overflow - saturate
                        if (fun_calc[31])
                            current_fun <= 16'h8000;  // Minimum negative
                        else
                            current_fun <= 16'h7FFF;  // Maximum positive
                    end else begin
                        current_fun <= fun_calc[15:0];
                    end
                end
                
                // Get current dp value
                current_dp <= dp_reg[dp_index];
                
                // Calculate time needed
                time_needed <= k * t_reg[current_coaster];
            end
            
            // Update candidate DP value
            if (state == UPDATE_DP) begin
                candidate_dp <= dp_reg[dp_index] + current_fun;
            end
        end
    end

    // Next state logic
    always @(*) begin
        // Default assignments
        next_state = state;
        next_coaster_idx = coaster_idx;
        next_ride_count = ride_count;
        next_dp_index = dp_index;
        next_dp_write_index = dp_write_index;
        next_current_fun = current_fun;
        next_current_dp = current_dp;
        next_candidate_dp = candidate_dp;
        next_best_fun = best_fun;
        next_time_needed = time_needed;
        next_k = k;
        next_current_coaster = current_coaster;
        next_cycle_count = cycle_count + 13'd1;

        case (state)
            IDLE: begin
                next_cycle_count = 13'd0;
                next_coaster_idx = 5'd0;
                next_ride_count = 5'd0;
                next_dp_index = 7'd0;
                next_dp_write_index = 7'd0;
                next_current_coaster = 3'd0;
                next_k = 5'd0;
                if (start) begin
                    next_state = LOAD_COEFF;
                end
            end

            LOAD_COEFF: begin
                if (coaster_idx < MAX_COASTERS) begin
                    next_coaster_idx = coaster_idx + 5'd1;
                end else begin
                    next_coaster_idx = 5'd0;
                    next_state = RESET_DP;
                    next_dp_index = 7'd0;
                end
            end

            RESET_DP: begin
                if (dp_index < MAX_TIME) begin
                    next_dp_index = dp_index + 7'd1;
                end else begin
                    next_dp_index = 7'd0;
                    next_current_coaster = 3'd0;
                    next_state = PROCESS;
                end
            end

            PROCESS: begin
                if (current_coaster < N) begin
                    next_k = 5'd1;
                    next_state = COMPUTE_RIDES;
                end else begin
                    next_state = FINISH;
                end
            end

            COMPUTE_RIDES: begin
                if (k <= MAX_RIDES) begin
                    // Calculate fun value
                    next_current_fun = 16'd0;
                    next_time_needed = k * t_reg[current_coaster];
                    
                    if (next_time_needed <= MAX_TIME && current_fun > 16'd0) begin
                        next_dp_index = next_time_needed;
                        next_dp_write_index = next_time_needed;
                        next_current_dp = dp_reg[next_time_needed];
                        next_state = UPDATE_DP;
                    end else begin
                        // Skip this ride count
                        if (k < MAX_RIDES) begin
                            next_k = k + 5'd1;
                        end else begin
                            next_current_coaster = current_coaster + 3'd1;
                            next_state = PROCESS;
                        end
                    end
                end else begin
                    next_current_coaster = current_coaster + 3'd1;
                    next_state = PROCESS;
                end
            end

            UPDATE_DP: begin
                // After update, move to next ride
                if (k < MAX_RIDES) begin
                    next_k = k + 5'd1;
                    next_state = COMPUTE_RIDES;
                end else begin
                    next_current_coaster = current_coaster + 3'd1;
                    next_state = PROCESS;
                end
            end

            FINISH: begin
                next_state = IDLE;
                next_cycle_count = 13'd0;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
        
        // Timeout protection
        if (cycle_count >= MAX_CYCLES) begin
            next_state = FINISH;
        end
    end

endmodule
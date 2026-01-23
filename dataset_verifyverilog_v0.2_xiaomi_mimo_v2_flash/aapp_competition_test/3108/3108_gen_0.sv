module max_average_subarray(
    input clk,
    input rst_n,
    input start,
    input [2:0] n,
    input [2:0] k,
    input [7:0] data_in,
    input [2:0] index,
    input write_en,
    output reg [15:0] result,
    output reg done,
    output reg valid
);

    // Fixed parameters
    parameter MAX_N = 8;
    parameter MIN_K = 3;
    
    // State encoding
    localparam IDLE = 3'b000;
    localparam LOAD = 3'b001;
    localparam COMPUTE = 3'b010;
    localparam DIVIDE = 3'b011;
    localparam UPDATE_MAX = 3'b100;
    localparam DONE = 3'b101;

    // Internal registers
    reg [2:0] current_state, next_state;
    reg [7:0] array_reg [0:MAX_N-1]; // Storage for 8 elements
    reg [2:0] len_cnt;                // Current subarray length
    reg [2:0] start_idx;              // Start index of subarray
    reg [2:0] curr_idx;               // Current index in subarray iteration
    reg [23:0] current_sum;           // 24-bit sum accumulator
    reg [23:0] max_avg;               // Store maximum average (scaled by 256)
    reg [23:0] division_sum;          // Sum for division
    reg [7:0] division_len;           // Length for division
    reg [23:0] quotient;              // Division result
    reg [5:0] shift_count;            // For division shifts
    reg loading_done;                 // Flag for loading complete
    reg [2:0] input_counter;          // Track inputs during loading
    
    // Temporary variables for division
    reg [23:0] div_temp;
    reg [7:0] len_temp;
    
    integer i;

    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start)
                    next_state = LOAD;
            end
            LOAD: begin
                // Wait for external loading or automatic load
                if (loading_done)
                    next_state = COMPUTE;
            end
            COMPUTE: begin
                // Initialize for sum calculation
                next_state = DIVIDE;
            end
            DIVIDE: begin
                // Wait for division to complete
                next_state = UPDATE_MAX;
            end
            UPDATE_MAX: begin
                // Check if done with all subarrays
                if (len_cnt > MAX_N || start_idx + len_cnt > MAX_N) begin
                    if (len_cnt < MAX_N && start_idx + 1 < MAX_N) begin
                        next_state = COMPUTE; // Next start index
                    end else if (len_cnt < MAX_N - 1) begin
                        next_state = COMPUTE; // Next length
                    end else begin
                        next_state = DONE;
                    end
                end else begin
                    next_state = COMPUTE; // Continue current length
                end
            end
            DONE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Control signals and datapath
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            result <= 16'b0;
            done <= 1'b0;
            valid <= 1'b0;
            len_cnt <= MIN_K;
            start_idx <= 3'b0;
            curr_idx <= 3'b0;
            current_sum <= 24'b0;
            max_avg <= 24'b0;
            loading_done <= 1'b0;
            input_counter <= 3'b0;
            shift_count <= 6'b0;
            quotient <= 24'b0;
            division_sum <= 24'b0;
            division_len <= 8'b0;
        end else begin
            case (current_state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    len_cnt <= MIN_K;
                    start_idx <= 3'b0;
                    curr_idx <= 3'b0;
                    max_avg <= 24'b0;
                    loading_done <= 1'b0;
                    // Handle manual write during IDLE
                    if (write_en && index < MAX_N) begin
                        array_reg[index] <= data_in;
                    end
                    // Auto-load if start is pressed
                    if (start) begin
                        input_counter <= 3'b0;
                    end
                end
                
                LOAD: begin
                    // Handle loading: manual or auto
                    if (write_en && index < MAX_N) begin
                        array_reg[index] <= data_in;
                    end
                    
                    // Simple auto-load simulation for 8 values
                    // In real hardware, this would wait for external inputs
                    // Here we simulate loading with a counter
                    if (input_counter < MAX_N) begin
                        // Simulate loading from data_in at specific cycles
                        // For synthesis, we rely on external write_en
                        if (write_en && index == input_counter) begin
                            input_counter <= input_counter + 1;
                        end
                    end else begin
                        loading_done <= 1'b1;
                    end
                    
                    // Alternative: if external signal indicates load complete
                    // loading_done <= ...;
                end
                
                COMPUTE: begin
                    // Start computing sum for subarray [start_idx, start_idx + len_cnt - 1]
                    if (curr_idx == start_idx) begin
                        current_sum <= {16'b0, array_reg[curr_idx]};
                    end else begin
                        current_sum <= current_sum + {16'b0, array_reg[curr_idx]};
                    end
                    
                    // Advance index
                    if (curr_idx < start_idx + len_cnt - 1) begin
                        curr_idx <= curr_idx + 1;
                    end else begin
                        curr_idx <= start_idx; // Reset for next state
                    end
                end
                
                DIVIDE: begin
                    // Fixed-point division: sum * 256 / length
                    // Using shift for powers of 2 or simple approximation
                    division_sum <= current_sum;
                    division_len <= {5'b0, len_cnt};
                    
                    // Calculate: quotient = (current_sum * 256) / len_cnt
                    // For simplicity and synthesis: use shift-right approximation
                    // Full division would require many cycles
                    // Here we use: result = (sum << 8) / len
                    
                    // Initialize division
                    shift_count <= 6'd0;
                    quotient <= (current_sum << 8); // Multiply by 256
                    div_temp <= (current_sum << 8);
                    len_temp <= {5'b0, len_cnt};
                end
                
                UPDATE_MAX: begin
                    // Complete division (simple iterative subtract for demo)
                    // Real implementation would need more states for full division
                    // Using shift approximation for len = 3,4,5,6,7,8
                    
                    // Compute division quotient
                    case (len_cnt)
                        3'd3: quotient <= division_sum * 85; // 256/3 ≈ 85
                        3'd4: quotient <= division_sum << 6; // 256/4 = 64
                        3'd5: quotient <= division_sum * 51; // 256/5 = 51.2
                        3'd6: quotient <= division_sum * 43; // 256/6 ≈ 42.67
                        3'd7: quotient <= division_sum * 37; // 256/7 ≈ 36.57
                        3'd8: quotient <= division_sum << 5; // 256/8 = 32
                        default: quotient <= division_sum << 8;
                    endcase
                    
                    // Compare with max
                    if (quotient > max_avg) begin
                        max_avg <= quotient;
                    end
                    
                    // Update counters for next iteration
                    if (start_idx + len_cnt < MAX_N) begin
                        // Next start index for same length
                        start_idx <= start_idx + 1;
                        curr_idx <= start_idx + 1;
                    end else begin
                        // Next length
                        start_idx <= 3'b0;
                        curr_idx <= 3'b0;
                        len_cnt <= len_cnt + 1;
                    end
                end
                
                DONE: begin
                    // Finalize result in Q8.8
                    result <= max_avg[15:0];
                    done <= 1'b1;
                    valid <= 1'b1;
                end
            endcase
        end
    end

endmodule
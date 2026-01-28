module GcdSplitModule (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] data_in,
    input wire valid_in,
    input wire last_in,
    output reg [1:0] result,
    output reg [15:0] assignment,
    output reg done,
    output reg ready
);

    // State declarations
    localparam [2:0] IDLE     = 3'd0;
    localparam [2:0] COLLECT  = 3'd1;
    localparam [2:0] COMPUTE  = 3'd2;
    localparam [2:0] CHECK    = 3'd3;
    localparam [2:0] OUTPUT   = 3'd4;
    localparam [2:0] FINISH   = 3'd5;
    
    // Constants
    localparam [3:0] MAX_NUMBERS = 4'd16;
    localparam [3:0] MAX_PRIMES  = 4'd8;
    localparam [7:0] MAX_MASK    = 8'hFF;
    localparam [7:0] DP_SIZE     = 8'd256;
    localparam [7:0] MAX_CYCLES  = 8'd250;
    
    // Hardcoded primes (2, 3, 5, 7, 11, 13, 17, 19)
    reg [31:0] primes [0:7];
    
    // State variables
    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    
    // Input buffer
    reg [31:0] number_buffer [0:15];
    reg [3:0] num_count;
    reg [3:0] num_read_ptr;
    reg [3:0] num_write_ptr;
    
    // Prime factor masks for each number
    reg [7:0] number_mask [0:15];
    
    // Unique prime tracking
    reg [7:0] unique_primes_mask;
    reg [3:0] unique_prime_count;
    
    // DP state for subset reachability
    reg [15:0] dp_assignment [0:255]; // Stores assignment for each mask
    reg dp_valid [0:255];             // Whether mask is reachable
    reg [7:0] current_mask;
    reg [3:0] number_idx;
    
    // Check phase variables
    reg [7:0] check_mask;
    reg [3:0] check_idx;
    reg [15:0] temp_assignment;
    reg [7:0] complement_mask;
    
    // Computation variables
    reg found_solution;
    reg [1:0] result_temp;
    reg [15:0] assignment_temp;
    
    integer i;
    
    // Initialize primes array (combinational for simplicity)
    always @(*) begin
        primes[0] = 32'd2;
        primes[1] = 32'd3;
        primes[2] = 32'd5;
        primes[3] = 32'd7;
        primes[4] = 32'd11;
        primes[5] = 32'd13;
        primes[6] = 32'd17;
        primes[7] = 32'd19;
    end
    
    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 2'd0;
            assignment <= 16'd0;
            done <= 1'b0;
            ready <= 1'b1;
            cycle_count <= 8'd0;
            
            // Initialize all registers
            num_count <= 4'd0;
            num_read_ptr <= 4'd0;
            num_write_ptr <= 4'd0;
            unique_primes_mask <= 8'd0;
            unique_prime_count <= 4'd0;
            current_mask <= 8'd0;
            number_idx <= 4'd0;
            check_mask <= 8'd0;
            check_idx <= 4'd0;
            temp_assignment <= 16'd0;
            complement_mask <= 8'd0;
            found_solution <= 1'b0;
            result_temp <= 2'd0;
            assignment_temp <= 16'd0;
            
            for (i = 0; i < 16; i = i + 1) begin
                number_buffer[i] <= 32'd0;
                number_mask[i] <= 8'd0;
            end
            
            for (i = 0; i < 256; i = i + 1) begin
                dp_assignment[i] <= 16'd0;
                dp_valid[i] <= 1'b0;
            end
            
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    ready <= 1'b1;
                    cycle_count <= 8'd0;
                    if (start) begin
                        // Reset buffers
                        num_count <= 4'd0;
                        num_write_ptr <= 4'd0;
                        unique_primes_mask <= 8'd0;
                        unique_prime_count <= 4'd0;
                        ready <= 1'b0;
                    end
                end
                
                COLLECT: begin
                    if (valid_in && num_write_ptr < MAX_NUMBERS) begin
                        // Store number
                        number_buffer[num_write_ptr] <= data_in;
                        
                        // Generate prime mask
                        for (i = 0; i < 8; i = i + 1) begin
                            if (data_in % primes[i] == 32'd0) begin
                                number_mask[num_write_ptr] <= number_mask[num_write_ptr] | (8'd1 << i);
                                unique_primes_mask <= unique_primes_mask | (8'd1 << i);
                            end
                        end
                        
                        num_write_ptr <= num_write_ptr + 4'd1;
                        num_count <= num_count + 4'd1;
                        
                        if (last_in) begin
                            num_count <= num_write_ptr + 4'd1;
                        end
                    end
                    
                    // Count unique primes
                    unique_prime_count <= 4'd0;
                    for (i = 0; i < 8; i = i + 1) begin
                        if (unique_primes_mask[i]) begin
                            unique_prime_count <= unique_prime_count + 4'd1;
                        end
                    end
                end
                
                COMPUTE: begin
                    // Initialize DP for first number
                    if (number_idx == 4'd0 && current_mask == 8'd0) begin
                        dp_valid[0] <= 1'b1;
                        dp_assignment[0] <= 16'd0;
                        current_mask <= 8'd0;
                    end else if (number_idx < num_count) begin
                        // BFS/DP: Update reachable states with current number
                        for (i = 0; i < 256; i = i + 1) begin
                            if (dp_valid[i]) begin
                                // Add current number's mask
                                dp_valid[i | number_mask[number_idx]] <= 1'b1;
                                // Update assignment - set bit for current number
                                dp_assignment[i | number_mask[number_idx]] <= dp_assignment[i] | (16'd1 << number_idx);
                            end
                        end
                        number_idx <= number_idx + 4'd1;
                    end
                    cycle_count <= cycle_count + 8'd1;
                end
                
                CHECK: begin
                    // Check if any subset covers all primes
                    if (check_idx < num_count && !found_solution) begin
                        // For each reachable mask
                        for (i = 0; i < 256; i = i + 1) begin
                            if (dp_valid[i] && (i == MAX_MASK)) begin
                                // Found subset that covers all primes
                                temp_assignment <= dp_assignment[i];
                                
                                // Verify complement also covers all primes
                                complement_mask <= 8'd0;
                                for (check_idx = 0; check_idx < num_count; check_idx = check_idx + 1) begin
                                    if (!(temp_assignment[check_idx])) begin
                                        complement_mask <= complement_mask | number_mask[check_idx];
                                    end
                                end
                                
                                if (complement_mask == MAX_MASK && temp_assignment != 16'd0 && temp_assignment != ((1 << num_count) - 1)) begin
                                    found_solution <= 1'b1;
                                    assignment_temp <= temp_assignment;
                                    result_temp <= 2'd1; // YES_GROUP1
                                end
                            end
                        end
                        check_idx <= check_idx + 4'd1;
                    end
                    
                    // Check for alternative (complement as group 1)
                    if (found_solution && result_temp == 2'd1) begin
                        result_temp <= 2'd2;
                    end
                    cycle_count <= cycle_count + 8'd1;
                end
                
                OUTPUT: begin
                    if (found_solution) begin
                        result <= result_temp;
                        assignment <= assignment_temp;
                    end else begin
                        result <= 2'd0;
                        assignment <= 16'd0;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    ready <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = state;
        
        case (state)
            IDLE: begin
                if (start) next_state = COLLECT;
            end
            
            COLLECT: begin
                if (last_in && valid_in) begin
                    if (num_count > 4'd1 && unique_prime_count > 4'd0) begin
                        next_state = COMPUTE;
                    end else begin
                        next_state = OUTPUT; // Not enough numbers or no primes
                    end
                end else if (num_count >= MAX_NUMBERS) begin
                    next_state = COMPUTE;
                end
            end
            
            COMPUTE: begin
                if (number_idx >= num_count || cycle_count >= MAX_CYCLES) begin
                    next_state = CHECK;
                end
            end
            
            CHECK: begin
                if (found_solution || check_idx >= num_count || cycle_count >= MAX_CYCLES) begin
                    next_state = OUTPUT;
                end
            end
            
            OUTPUT: begin
                next_state = FINISH;
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule
module MaxNumberKSwaps (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] digits_in [0:7],
    input wire [2:0] num_digits,
    input wire [4:0] k,
    output reg [3:0] digits_out [0:7],
    output reg valid,
    output reg done
);

    // State declarations
    localparam [3:0] IDLE        = 4'd0;
    localparam [3:0] INIT        = 4'd1;
    localparam [3:0] PROCESS     = 4'd2;
    localparam [3:0] EVALUATE    = 4'd3;
    localparam [4:0] FINISH      = 4'd4;
    localparam [3:0] ERROR       = 4'd5;

    // Internal registers and wires
    reg [3:0] state, next_state;
    reg [3:0] best_digits [0:7];
    reg [4:0] best_score;
    reg [4:0] best_swaps;
    
    // State buffer: stores current state and swaps left
    // Each entry: [39:0] = {swaps_left[3:0], digits[0][3:0], ..., digits[7][3:0]}
    reg [39:0] state_buffer [0:63];
    reg [6:0] head_ptr;
    reg [6:0] tail_ptr;
    reg [6:0] buffer_count;
    
    // Temporary state storage for generating new states
    reg [39:0] temp_state;
    reg [39:0] new_state;
    reg [2:0] i, j;
    reg [2:0] swap_i, swap_j;
    reg [4:0] swaps_left;
    reg [3:0] temp_digit;
    reg [3:0] temp_digits [0:7];
    
    // Counters for bounds
    reg [7:0] cycle_counter;
    localparam [7:0] MAX_CYCLES = 8'd200;
    
    // Helper signals
    reg buffer_full;
    reg buffer_empty;
    reg processing_done;
    reg evaluation_done;
    
    integer idx, elem;

    // Function to convert digit array to score (higher is better)
    function automatic [4:0] calculate_score;
        input [3:0] digits [0:7];
        input [2:0] nd;
        reg [4:0] score;
        reg [3:0] val;
        integer k;
        begin
            score = 5'd0;
            for (k = 0; k < 8; k = k + 1) begin
                if (k < nd) begin
                    // Multiply by position value (10^(7-k)) truncated
                    // Simplified: prioritize leading digits more
                    val = digits[k];
                    score = score + (val << (3 * (7 - k)));
                    // Limit to prevent overflow, just use sum
                    if (k < 2) score = score + (val * 8'd100);
                    else if (k < 4) score = score + (val * 8'd10);
                    else score = score + val;
                end
            end
            calculate_score = score;
        end
    endfunction

    // Update buffer pointers
    always @(*) begin
        buffer_full = (buffer_count >= 7'd64);
        buffer_empty = (buffer_count == 7'd0);
    end

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            valid <= 1'b0;
            done <= 1'b0;
            cycle_counter <= 8'd0;
            buffer_count <= 7'd0;
            head_ptr <= 7'd0;
            tail_ptr <= 7'd0;
            best_score <= 5'd0;
            best_swaps <= 5'd16;
            processing_done <= 1'b0;
            evaluation_done <= 1'b0;
            // Initialize all digit arrays
            for (elem = 0; elem < 8; elem = elem + 1) begin
                best_digits[elem] <= 4'd0;
                digits_out[elem] <= 4'd0;
                temp_digits[elem] <= 4'd0;
            end
        end else begin
            cycle_counter <= cycle_counter + 8'd1;
            
            case (state)
                IDLE: begin
                    valid <= 1'b0;
                    done <= 1'b0;
                    buffer_count <= 7'd0;
                    head_ptr <= 7'd0;
                    tail_ptr <= 7'd0;
                    best_score <= 5'd0;
                    best_swaps <= 5'd16;
                    processing_done <= 1'b0;
                    evaluation_done <= 1'b0;
                    
                    if (start) begin
                        state <= INIT;
                        cycle_counter <= 8'd0;
                    end else begin
                        state <= IDLE;
                    end
                end
                
                INIT: begin
                    // Load initial state into buffer
                    if (num_digits >= 3'd1 && num_digits <= 3'd8 && k <= 5'd16) begin
                        // Pack initial state: {k, digits[0], ..., digits[7]}
                        state_buffer[head_ptr] <= {k[3:0], 
                            digits_in[7], digits_in[6], digits_in[5], digits_in[4],
                            digits_in[3], digits_in[2], digits_in[1], digits_in[0]};
                        head_ptr <= head_ptr + 7'd1;
                        buffer_count <= 7'd1;
                        
                        // Set initial best as input (0 swaps)
                        for (elem = 0; elem < 8; elem = elem + 1) begin
                            best_digits[elem] <= digits_in[elem];
                        end
                        best_score <= calculate_score(digits_in, num_digits);
                        best_swaps <= 5'd0;
                        
                        processing_done <= 1'b0;
                        evaluation_done <= 1'b0;
                        
                        if (k == 5'd0) begin
                            // 0 swaps: output is input
                            state <= FINISH;
                        end else begin
                            state <= PROCESS;
                        end
                    end else begin
                        state <= ERROR;
                    end
                end
                
                PROCESS: begin
                    // Extract state from buffer
                    if (!buffer_empty && !processing_done) begin
                        temp_state <= state_buffer[tail_ptr];
                        tail_ptr <= tail_ptr + 7'd1;
                        buffer_count <= buffer_count - 7'd1;
                        
                        // Prepare to generate new states
                        i <= 3'd0;
                        j <= 3'd1;
                        swap_i <= 3'd0;
                        swap_j <= 3'd1;
                        state <= EVALUATE;
                    end else if (buffer_empty) begin
                        processing_done <= 1'b1;
                        state <= FINISH;
                    end else begin
                        state <= FINISH;
                    end
                end
                
                EVALUATE: begin
                    // Decode current state
                    swaps_left <= temp_state[3:0];
                    temp_digits[0] <= temp_state[7:4];
                    temp_digits[1] <= temp_state[11:8];
                    temp_digits[2] <= temp_state[15:12];
                    temp_digits[3] <= temp_state[19:16];
                    temp_digits[4] <= temp_state[23:20];
                    temp_digits[5] <= temp_state[27:24];
                    temp_digits[6] <= temp_state[31:28];
                    temp_digits[7] <= temp_state[35:32];
                    
                    if (swaps_left > 4'd0) begin
                        // Check for valid swap (must be within num_digits)
                        if (swap_i < num_digits && swap_j < num_digits && swap_i != swap_j) begin
                            // Perform swap
                            temp_digits[swap_i] <= temp_state[(swap_i * 4) + 7: (swap_i * 4) + 4];
                            temp_digits[swap_j] <= temp_state[(swap_j * 4) + 7: (swap_j * 4) + 4];
                            // Actually swap in next cycle
                            state <= 4'd6; // Special state for swap execution
                        end else begin
                            // Move to next pair
                            if (swap_j < 3'd7) begin
                                swap_j <= swap_j + 3'd1;
                            end else begin
                                swap_j <= swap_i + 3'd2;
                                if (swap_i < 3'd6) begin
                                    swap_i <= swap_i + 3'd1;
                                end else begin
                                    // All pairs processed
                                    state <= PROCESS;
                                end
                            end
                        end
                    end else begin
                        // No more swaps, evaluate this state
                        // Update best if better
                        if (best_swaps == 5'd16 || calculate_score(temp_digits, num_digits) > best_score) begin
                            best_score <= calculate_score(temp_digits, num_digits);
                            best_swaps <= 5'd16 - swaps_left;
                            for (elem = 0; elem < 8; elem = elem + 1) begin
                                best_digits[elem] <= temp_digits[elem];
                            end
                        end
                        state <= PROCESS;
                    end
                end
                
                4'd6: begin // Swap execution state
                    // Actually perform the swap
                    temp_digits[swap_i] <= temp_state[(swap_j * 4) + 7: (swap_j * 4) + 4];
                    temp_digits[swap_j] <= temp_state[(swap_i * 4) + 7: (swap_i * 4) + 4];
                    
                    // Check leading zero constraint
                    // Since we only swap within valid digits, leading zero constraint is satisfied
                    // Create new state with decremented swaps
                    if (!buffer_full) begin
                        state_buffer[head_ptr] <= {(swaps_left - 4'd1), 
                            temp_digits[7], temp_digits[6], temp_digits[5], temp_digits[4],
                            temp_digits[3], temp_digits[2], temp_digits[1], temp_digits[0]};
                        head_ptr <= head_ptr + 7'd1;
                        buffer_count <= buffer_count + 7'd1;
                    end
                    
                    // Move to next pair
                    if (swap_j < 3'd7) begin
                        swap_j <= swap_j + 3'd1;
                    end else begin
                        swap_j <= swap_i + 3'd2;
                        if (swap_i < 3'd6) begin
                            swap_i <= swap_i + 3'd1;
                        end else begin
                            state <= PROCESS;
                        end
                    end
                end
                
                FINISH: begin
                    // Check if we have processed all states
                    // or reached max cycles or completed exactly k swaps
                    if (cycle_counter >= MAX_CYCLES || buffer_empty || best_swaps == k) begin
                        // Output the best result
                        for (elem = 0; elem < 8; elem = elem + 1) begin
                            digits_out[elem] <= best_digits[elem];
                        end
                        valid <= 1'b1;
                        done <= 1'b1;
                        state <= IDLE;
                    end else begin
                        state <= PROCESS;
                    end
                end
                
                ERROR: begin
                    // Invalid inputs
                    for (elem = 0; elem < 8; elem = elem + 1) begin
                        digits_out[elem] <= 4'd0;
                    end
                    valid <= 1'b0;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule
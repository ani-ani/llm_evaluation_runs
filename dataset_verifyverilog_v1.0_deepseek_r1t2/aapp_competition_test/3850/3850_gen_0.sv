module key_person_assignment (
    input clk,
    input rst_n,
    input start,
    input signed [31:0] people_pos[0:7],
    input signed [31:0] key_pos[0:15],
    input signed [31:0] office_pos,
    input [3:0] valid_people,
    input [4:0] valid_keys,
    output reg signed [31:0] min_max_time,
    output reg done
);

    // State declarations
    localparam [3:0] IDLE          = 4'd0;
    localparam [3:0] SORT_PEOPLE   = 4'd1;
    localparam [3:0] SORT_KEYS     = 4'd2;
    localparam [3:0] INIT_ASSIGN   = 4'd3;
    localparam [3:0] CALC_MAX_TIME = 4'd4;
    localparam [3:0] CHECK_ASSIGN  = 4'd5;
    localparam [3:0] FINISH        = 4'd6;

    reg [3:0] state, next_state;
    reg [7:0] cycles;  // Cycle counter for timeout
    
    // Sorted copy arrays
    reg signed [31:0] sorted_people[0:7];
    reg signed [31:0] sorted_keys[0:15];
    
    // Sorting registers
    reg [2:0] sort_i, sort_j;
    reg sort_swap_flag;
    
    // Assignment registers
    reg [4:0] assign_start;  // Current start index
    reg [3:0] person_idx;    // Current person index
    reg signed [31:0] current_max, candidate_min;
    
    // Distance calculation
    wire signed [31:0] person_to_key;
    wire signed [31:0] key_to_office;
    
    // Absolute value function
    function automatic signed [31:0] abs32(input signed [31:0] val);
        abs32 = val[31] ? -val : val;
    endfunction
    
    // Manhattan distance calculator
    assign person_to_key = abs32(sorted_people[person_idx] - sorted_keys[assign_start + person_idx]);
    assign key_to_office = abs32(sorted_keys[assign_start + person_idx] - office_pos);
    
    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            cycles <= 8'd0;
            min_max_time <= 32'd0;
            
            // Clear arrays
            for (int i = 0; i < 8; i = i + 1) begin
                sorted_people[i] <= 32'd0;
            end
            for (int i = 0; i < 16; i = i + 1) begin
                sorted_keys[i] <= 32'd0;
            end
        end
        else begin
            cycles <= cycles + 8'd1;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Copy input arrays
                        for (int i = 0; i < 8; i = i + 1) begin
                            sorted_people[i] <= people_pos[i];
                        end
                        for (int i = 0; i < 16; i = i + 1) begin
                            sorted_keys[i] <= key_pos[i];
                        end
                        state <= SORT_PEOPLE;
                        cycles <= 8'd0;
                    end
                end
                
                SORT_PEOPLE: begin
                    // Bubble sort for people
                    if (sort_i < valid_people - 4'd1) begin
                        if (sort_j < valid_people - sort_i - 4'd1) begin
                            if (sorted_people[sort_j] > sorted_people[sort_j + 1]) begin
                                // Swap
                                sorted_people[sort_j] <= sorted_people[sort_j + 1];
                                sorted_people[sort_j + 1] <= sorted_people[sort_j];
                            end
                            sort_j <= sort_j + 3'd1;
                        end
                        else begin
                            sort_i <= sort_i + 3'd1;
                            sort_j <= 3'd0;
                        end
                    end
                    else begin
                        state <= SORT_KEYS;
                        sort_i <= 3'd0;
                        sort_j <= 3'd0;
                    end
                end
                
                SORT_KEYS: begin
                    // Bubble sort for keys
                    if (sort_i < valid_keys - 5'd1) begin
                        if (sort_j < valid_keys - sort_i - 5'd1) begin
                            if (sorted_keys[sort_j] > sorted_keys[sort_j + 1]) begin
                                // Swap
                                sorted_keys[sort_j] <= sorted_keys[sort_j + 1];
                                sorted_keys[sort_j + 1] <= sorted_keys[sort_j];
                            end
                            sort_j <= sort_j + 3'd1;
                        end
                        else begin
                            sort_i <= sort_i + 3'd1;
                            sort_j <= 3'd0;
                        end
                    end
                    else begin
                        state <= INIT_ASSIGN;
                        assign_start <= 5'd0;
                        candidate_min <= 32'h7FFFFFFF;  // Max positive
                    end
                end
                
                INIT_ASSIGN: begin
                    if (assign_start <= (valid_keys - valid_people)) begin
                        person_idx <= 4'd0;
                        current_max <= 32'd0;
                        state <= CALC_MAX_TIME;
                    end
                    else begin
                        state <= FINISH;
                        min_max_time <= candidate_min;
                    end
                end
                
                CALC_MAX_TIME: begin
                    // Calculate travel time: person to key + key to office
                    if (person_idx < valid_people) begin
                        // Update current_max
                        if ((person_to_key + key_to_office) > current_max) begin
                            current_max <= person_to_key + key_to_office;
                        end
                        person_idx <= person_idx + 4'd1;
                    end
                    else begin
                        // Compare with candidate_min
                        if (current_max < candidate_min) begin
                            candidate_min <= current_max;
                        end
                        assign_start <= assign_start + 5'd1;
                        state <= INIT_ASSIGN;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
            
            // Timeout handling
            if (cycles >= 8'd250) begin
                state <= FINISH;
                min_max_time <= (candidate_min == 32'h7FFFFFFF) ? 32'd0 : candidate_min;
            end
        end
    end
    
    // Initialize sorting variables on reset
    always @(negedge rst_n or posedge clk) begin
        if (!rst_n) begin
            sort_i <= 3'd0;
            sort_j <= 3'd0;
        end
        else if (state == SORT_PEOPLE || state == SORT_KEYS) begin
            if (sort_i == 3'd0 && sort_j == 3'd0) begin
                sort_i <= 3'd1;
                sort_j <= 3'd0;
            end
        end
    end
endmodule

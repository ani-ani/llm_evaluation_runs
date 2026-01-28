module KeyAssignment (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] people_pos [0:7],
    input wire [31:0] key_pos [0:15],
    input wire [31:0] office_pos,
    input wire [2:0] valid_people,
    input wire [4:0] valid_keys,
    output reg [31:0] min_max_time,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] SORT_PEOPLE = 3'd1;
    localparam [2:0] SORT_KEYS = 3'd2;
    localparam [2:0] COMPUTE = 3'd3;
    localparam [2:0] UPDATE_MIN = 3'd4;
    localparam [2:0] FINISH = 3'd5;

    // Internal registers
    reg [2:0] state, next_state;
    reg [31:0] sorted_people [0:7];
    reg [31:0] sorted_keys [0:15];
    reg [2:0] people_idx;
    reg [4:0] key_idx;
    reg [2:0] swap_idx;
    reg [4:0] key_swap_idx;
    reg [4:0] key_offset;
    reg [2:0] assignment_idx;
    reg [31:0] current_max_time;
    reg [15:0] cycle_counter;
    reg [31:0] temp_dist;
    reg [63:0] calc_temp;
    reg people_sort_done;
    reg key_sort_done;
    reg [2:0] i_temp;
    reg [4:0] k_temp;

    localparam [15:0] MAX_CYCLES = 16'd1000;

    // Bubble sort for people (up to 8 elements)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i_temp = 0; i_temp < 8; i_temp = i_temp + 1) begin
                sorted_people[i_temp] <= 32'd0;
            end
            people_idx <= 3'd0;
            swap_idx <= 3'd0;
            people_sort_done <= 1'b0;
        end else if (state == SORT_PEOPLE) begin
            if (people_idx < valid_people - 1) begin
                if (swap_idx < valid_people - 1 - people_idx) begin
                    if (sorted_people[swap_idx] > sorted_people[swap_idx + 1]) begin
                        // Swap
                        sorted_people[swap_idx] <= sorted_people[swap_idx + 1];
                        sorted_people[swap_idx + 1] <= sorted_people[swap_idx];
                    end
                    swap_idx <= swap_idx + 1;
                end else begin
                    swap_idx <= 0;
                    people_idx <= people_idx + 1;
                end
            end else begin
                people_sort_done <= 1'b1;
            end
        end
    end

    // Bubble sort for keys (up to 16 elements)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (k_temp = 0; k_temp < 16; k_temp = k_temp + 1) begin
                sorted_keys[k_temp] <= 32'd0;
            end
            key_idx <= 5'd0;
            key_swap_idx <= 5'd0;
            key_sort_done <= 1'b0;
        end else if (state == SORT_KEYS) begin
            if (key_idx < valid_keys - 1) begin
                if (key_swap_idx < valid_keys - 1 - key_idx) begin
                    if (sorted_keys[key_swap_idx] > sorted_keys[key_swap_idx + 1]) begin
                        // Swap
                        sorted_keys[key_swap_idx] <= sorted_keys[key_swap_idx + 1];
                        sorted_keys[key_swap_idx + 1] <= sorted_keys[key_swap_idx];
                    end
                    key_swap_idx <= key_swap_idx + 1;
                end else begin
                    key_swap_idx <= 5'd0;
                    key_idx <= key_idx + 1;
                end
            end else begin
                key_sort_done <= 1'b1;
            end
        end
    end

    // Main computation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            min_max_time <= 32'hFFFFFFFF;
            cycle_counter <= 16'd0;
            assignment_idx <= 3'd0;
            key_offset <= 5'd0;
            current_max_time <= 32'd0;
            calc_temp <= 64'd0;
            temp_dist <= 32'd0;
        end else begin
            cycle_counter <= cycle_counter + 16'd1;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_counter <= 16'd0;
                    min_max_time <= 32'hFFFFFFFF;
                    if (start) begin
                        // Load initial positions
                        for (i_temp = 0; i_temp < 8; i_temp = i_temp + 1) begin
                            if (i_temp < valid_people)
                                sorted_people[i_temp] <= people_pos[i_temp];
                            else
                                sorted_people[i_temp] <= 32'd0;
                        end
                        for (k_temp = 0; k_temp < 16; k_temp = k_temp + 1) begin
                            if (k_temp < valid_keys)
                                sorted_keys[k_temp] <= key_pos[k_temp];
                            else
                                sorted_keys[k_temp] <= 32'd0;
                        end
                        people_sort_done <= 1'b0;
                        key_sort_done <= 1'b0;
                        people_idx <= 3'd0;
                        swap_idx <= 3'd0;
                        key_idx <= 5'd0;
                        key_swap_idx <= 5'd0;
                        state <= SORT_PEOPLE;
                    end
                end

                SORT_PEOPLE: begin
                    if (people_sort_done) begin
                        state <= SORT_KEYS;
                    end
                end

                SORT_KEYS: begin
                    if (key_sort_done) begin
                        assignment_idx <= 3'd0;
                        key_offset <= 5'd0;
                        current_max_time <= 32'd0;
                        state <= COMPUTE;
                    end
                end

                COMPUTE: begin
                    if (assignment_idx < valid_people) begin
                        // Calculate distance: |sorted_people[assignment_idx] - sorted_keys[key_offset + assignment_idx]|
                        if (sorted_people[assignment_idx] > sorted_keys[key_offset + assignment_idx]) begin
                            calc_temp <= sorted_people[assignment_idx] - sorted_keys[key_offset + assignment_idx];
                        end else begin
                            calc_temp <= sorted_keys[key_offset + assignment_idx] - sorted_people[assignment_idx];
                        end
                        temp_dist <= calc_temp[31:0];
                        
                        // Compare with current max
                        if (calc_temp[31:0] > current_max_time) begin
                            current_max_time <= calc_temp[31:0];
                        end
                        
                        assignment_idx <= assignment_idx + 1;
                    end else begin
                        // Done with this assignment, check if valid
                        if (current_max_time < min_max_time) begin
                            state <= UPDATE_MIN;
                        end else begin
                            // Next key offset
                            if (key_offset < (valid_keys - valid_people)) begin
                                key_offset <= key_offset + 1;
                                assignment_idx <= 3'd0;
                                current_max_time <= 32'd0;
                            end else begin
                                state <= FINISH;
                            end
                        end
                    end
                end

                UPDATE_MIN: begin
                    min_max_time <= current_max_time;
                    // Next key offset
                    if (key_offset < (valid_keys - valid_people)) begin
                        key_offset <= key_offset + 1;
                        assignment_idx <= 3'd0;
                        current_max_time <= 32'd0;
                        state <= COMPUTE;
                    end else begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
            
            // Timeout protection
            if (cycle_counter >= MAX_CYCLES && state != IDLE && state != FINISH) begin
                state <= FINISH;
                min_max_time <= 32'hFFFFFFFF;
            end
        end
    end

endmodule
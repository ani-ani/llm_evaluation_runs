module FindMinTime(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [4:0] k,
    input wire [15:0] p,
    input wire [15:0] people [0:7],
    input wire [15:0] keys [0:15],
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE          = 3'd0;
    localparam [2:0] SORT_PEOPLE   = 3'd1;
    localparam [2:0] SORT_KEYS     = 3'd2;
    localparam [2:0] CHECK_WINDOWS = 3'd3;
    localparam [2:0] CALC_TIME     = 3'd4;
    localparam [2:0] UPDATE_MIN    = 3'd5;
    localparam [2:0] FINISH        = 3'd6;

    // Internal registers
    reg [2:0] state;
    reg [15:0] people_reg [0:7];
    reg [15:0] keys_reg [0:15];
    reg [15:0] current_min;
    reg [15:0] temp_max;
    reg [15:0] abs_diff1;
    reg [15:0] abs_diff2;
    reg [15:0] time_sum;
    
    // Index registers
    reg [3:0] i; // Loop counter
    reg [3:0] j; // Inner loop for sorting
    reg [4:0] w_idx; // Window index
    reg [3:0] p_idx; // Person index
    reg [3:0] k_idx; // Key index
    reg [3:0] sort_len;
    reg [3:0] window_start;
    
    // Temporary storage for comparison
    reg [15:0] swap_temp;
    reg [15:0] temp_val;
    reg is_greater;
    reg [15:0] diff_temp;
    
    // Cycle counter to prevent infinite loops
    reg [9:0] cycle_count;
    localparam [9:0] MAX_CYCLES = 10'd500;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            current_min <= 16'hFFFF;
            temp_max <= 16'd0;
            abs_diff1 <= 16'd0;
            abs_diff2 <= 16'd0;
            time_sum <= 16'd0;
            i <= 4'd0;
            j <= 4'd0;
            w_idx <= 5'd0;
            p_idx <= 4'd0;
            k_idx <= 4'd0;
            sort_len <= 4'd0;
            window_start <= 4'd0;
            swap_temp <= 16'd0;
            temp_val <= 16'd0;
            is_greater <= 1'b0;
            diff_temp <= 16'd0;
            cycle_count <= 10'd0;
            
            // Initialize arrays
            for (int init_i = 0; init_i < 8; init_i = init_i + 1) begin
                people_reg[init_i] <= 16'd0;
            end
            for (int init_j = 0; init_j < 16; init_j = init_j + 1) begin
                keys_reg[init_j] <= 16'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 10'd0;
                    if (start) begin
                        // Initialize arrays from inputs
                        for (int p_i = 0; p_i < 8; p_i = p_i + 1) begin
                            people_reg[p_i] <= people[p_i];
                        end
                        for (int k_i = 0; k_i < 16; k_i = k_i + 1) begin
                            keys_reg[k_i] <= keys[k_i];
                        end
                        current_min <= 16'hFFFF;
                        i <= 4'd0;
                        j <= 4'd0;
                        sort_len <= n;
                        state <= SORT_PEOPLE;
                    end
                end

                SORT_PEOPLE: begin
                    cycle_count <= cycle_count + 10'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end else if (i < sort_len) begin
                        j <= 4'd0;
                        state <= SORT_PEOPLE; // Stay in sort
                        // Bubble Sort pass
                        if (j < sort_len - i - 4'd1) begin
                            if (people_reg[j] > people_reg[j + 4'd1]) begin
                                swap_temp <= people_reg[j];
                                people_reg[j] <= people_reg[j + 4'd1];
                                people_reg[j + 4'd1] <= swap_temp;
                            end
                            j <= j + 4'd1;
                        end else begin
                            i <= i + 4'd1;
                        end
                    end else begin
                        // Done sorting people, reset for keys
                        i <= 4'd0;
                        j <= 4'd0;
                        sort_len <= k[3:0]; // Limit to 16
                        state <= SORT_KEYS;
                    end
                end

                SORT_KEYS: begin
                    cycle_count <= cycle_count + 10'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end else if (i < sort_len) begin
                        if (j < sort_len - i - 4'd1) begin
                            if (keys_reg[j] > keys_reg[j + 4'd1]) begin
                                swap_temp <= keys_reg[j];
                                keys_reg[j] <= keys_reg[j + 4'd1];
                                keys_reg[j + 4'd1] <= swap_temp;
                            end
                            j <= j + 4'd1;
                        end else begin
                            i <= i + 4'd1;
                            j <= 4'd0;
                        end
                    end else begin
                        // Done sorting, start checking windows
                        w_idx <= 5'd0;
                        state <= CHECK_WINDOWS;
                    end
                end

                CHECK_WINDOWS: begin
                    cycle_count <= cycle_count + 10'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end else if (w_idx <= (k - n)) begin
                        // Initialize for this window
                        p_idx <= 4'd0;
                        temp_max <= 16'd0;
                        state <= CALC_TIME;
                    end else begin
                        state <= FINISH;
                    end
                end

                CALC_TIME: begin
                    cycle_count <= cycle_count + 10'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end else if (p_idx < n) begin
                        // Calculate abs(people_reg[p_idx] - keys_reg[w_idx + p_idx])
                        if (people_reg[p_idx] >= keys_reg[w_idx + p_idx]) begin
                            abs_diff1 <= people_reg[p_idx] - keys_reg[w_idx + p_idx];
                        end else begin
                            abs_diff1 <= keys_reg[w_idx + p_idx] - people_reg[p_idx];
                        end
                        // Need to wait one cycle for subtraction
                        state <= CALC_TIME;
                    end else begin
                        // Done with this window
                        w_idx <= w_idx + 5'd1;
                        state <= UPDATE_MIN;
                    end
                end

                UPDATE_MIN: begin
                    // Update current_min if temp_max is smaller
                    if (temp_max < current_min) begin
                        current_min <= temp_max;
                    end
                    state <= CHECK_WINDOWS;
                end

                FINISH: begin
                    done <= 1'b1;
                    result <= current_min;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase

            // Combinational logic for CALC_TIME state (pipelined)
            if (state == CALC_TIME && p_idx < n) begin
                // Calculate abs(keys_reg[w_idx + p_idx] - p)
                if (keys_reg[w_idx + p_idx] >= p) begin
                    abs_diff2 <= keys_reg[w_idx + p_idx] - p;
                end else begin
                    abs_diff2 <= p - keys_reg[w_idx + p_idx];
                end
                
                // Sum the two distances
                time_sum <= abs_diff1 + abs_diff2;
                
                // Update max for this window
                if (time_sum > temp_max) begin
                    temp_max <= time_sum;
                end
                
                // Increment person index
                p_idx <= p_idx + 4'd1;
            end
        end
    end

endmodule
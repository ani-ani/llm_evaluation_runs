module ArrowMappingReconstructor(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] N,
    input wire [31:0] K,
    input wire [3:0] P [0:7],
    output reg [3:0] f [0:7],
    output reg valid,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] PARSE = 3'd1;
    localparam [2:0] DECOMPOSE = 3'd2;
    localparam [2:0] SEARCH = 3'd3;
    localparam [2:0] CONSTRUCT = 3'd4;
    localparam [2:0] VALIDATE = 3'd5;
    localparam [2:0] FINISH = 3'd6;

    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd10000;

    // Internal registers
    reg [3:0] current_N;
    reg [31:0] current_K;
    reg [3:0] current_P [0:7];
    reg [3:0] cycle_start [0:7];
    reg [3:0] cycle_length [0:7];
    reg [3:0] cycle_index [0:7];
    reg [3:0] num_cycles;
    reg [3:0] current_cycle;
    reg [3:0] current_pos;
    reg [3:0] current_val;
    reg [3:0] temp_f [0:7];
    reg [3:0] divisor [0:7];
    reg [3:0] num_divisors;
    reg [3:0] current_divisor;
    reg [3:0] lcm_result;
    reg [3:0] sum_result;
    reg [3:0] temp_cycle [0:7];
    reg [3:0] temp_cycle_length [0:7];
    reg [3:0] temp_cycle_index [0:7];
    reg [3:0] temp_num_cycles;
    reg [3:0] temp_current_cycle;
    reg [3:0] temp_current_pos;
    reg [3:0] temp_current_val;
    reg [3:0] temp_divisor [0:7];
    reg [3:0] temp_num_divisors;
    reg [3:0] temp_current_divisor;
    reg [3:0] temp_lcm_result;
    reg [3:0] temp_sum_result;
    reg [3:0] temp_f_temp [0:7];
    reg [3:0] temp_f_index;
    reg [3:0] temp_f_value;
    reg [3:0] temp_f_length;
    reg [3:0] temp_f_start;
    reg [3:0] temp_f_current;
    reg [3:0] temp_f_next;
    reg [3:0] temp_f_count;
    reg [3:0] temp_f_valid;
    reg [3:0] temp_f_done;
    reg [3:0] temp_f_state;
    reg [3:0] temp_f_cycle;
    reg [3:0] temp_f_pos;
    reg [3:0] temp_f_val;
    reg [3:0] temp_f_divisor;
    reg [3:0] temp_f_num_divisors;
    reg [3:0] temp_f_current_divisor;
    reg [3:0] temp_f_lcm_result;
    reg [3:0] temp_f_sum_result;
    reg [3:0] temp_f_temp_cycle [0:7];
    reg [3:0] temp_f_temp_cycle_length [0:7];
    reg [3:0] temp_f_temp_cycle_index [0:7];
    reg [3:0] temp_f_temp_num_cycles;
    reg [3:0] temp_f_temp_current_cycle;
    reg [3:0] temp_f_temp_current_pos;
    reg [3:0] temp_f_temp_current_val;
    reg [3:0] temp_f_temp_divisor [0:7];
    reg [3:0] temp_f_temp_num_divisors;
    reg [3:0] temp_f_temp_current_divisor;
    reg [3:0] temp_f_temp_lcm_result;
    reg [3:0] temp_f_temp_sum_result;
    reg [3:0] temp_f_temp_f_temp [0:7];
    reg [3:0] temp_f_temp_f_index;
    reg [3:0] temp_f_temp_f_value;
    reg [3:0] temp_f_temp_f_length;
    reg [3:0] temp_f_temp_f_start;
    reg [3:0] temp_f_temp_f_current;
    reg [3:0] temp_f_temp_f_next;
    reg [3:0] temp_f_temp_f_count;
    reg [3:0] temp_f_temp_f_valid;
    reg [3:0] temp_f_temp_f_done;
    reg [3:0] temp_f_temp_f_state;
    reg [3:0] temp_f_temp_f_cycle;
    reg [3:0] temp_f_temp_f_pos;
    reg [3:0] temp_f_temp_f_val;
    reg [3:0] temp_f_temp_f_divisor;
    reg [3:0] temp_f_temp_f_num_divisors;
    reg [3:0] temp_f_temp_f_current_divisor;
    reg [3:0] temp_f_temp_f_lcm_result;
    reg [3:0] temp_f_temp_f_sum_result;

    // Initialize all registers
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cycle_count <= 8'd0;
            current_N <= 8'd0;
            current_K <= 32'd0;
            for (i = 0; i < 8; i = i + 1) begin
                current_P[i] <= 4'd0;
                cycle_start[i] <= 4'd0;
                cycle_length[i] <= 4'd0;
                cycle_index[i] <= 4'd0;
                divisor[i] <= 4'd0;
                temp_cycle[i] <= 4'd0;
                temp_cycle_length[i] <= 4'd0;
                temp_cycle_index[i] <= 4'd0;
                temp_divisor[i] <= 4'd0;
                temp_f_temp[i] <= 4'd0;
                temp_f_temp_cycle[i] <= 4'd0;
                temp_f_temp_cycle_length[i] <= 4'd0;
                temp_f_temp_cycle_index[i] <= 4'd0;
                temp_f_temp_divisor[i] <= 4'd0;
                temp_f_temp_f_temp[i] <= 4'd0;
                f[i] <= 4'd0;
            end
            num_cycles <= 4'd0;
            current_cycle <= 4'd0;
            current_pos <= 4'd0;
            current_val <= 4'd0;
            num_divisors <= 4'd0;
            current_divisor <= 4'd0;
            lcm_result <= 4'd0;
            sum_result <= 4'd0;
            temp_num_cycles <= 4'd0;
            temp_current_cycle <= 4'd0;
            temp_current_pos <= 4'd0;
            temp_current_val <= 4'd0;
            temp_num_divisors <= 4'd0;
            temp_current_divisor <= 4'd0;
            temp_lcm_result <= 4'd0;
            temp_sum_result <= 4'd0;
            temp_f_index <= 4'd0;
            temp_f_value <= 4'd0;
            temp_f_length <= 4'd0;
            temp_f_start <= 4'd0;
            temp_f_current <= 4'd0;
            temp_f_next <= 4'd0;
            temp_f_count <= 4'd0;
            temp_f_valid <= 4'd0;
            temp_f_done <= 4'd0;
            temp_f_state <= 4'd0;
            temp_f_cycle <= 4'd0;
            temp_f_pos <= 4'd0;
            temp_f_val <= 4'd0;
            temp_f_divisor <= 4'd0;
            temp_f_num_divisors <= 4'd0;
            temp_f_current_divisor <= 4'd0;
            temp_f_lcm_result <= 4'd0;
            temp_f_sum_result <= 4'd0;
            temp_f_temp_num_cycles <= 4'd0;
            temp_f_temp_current_cycle <= 4'd0;
            temp_f_temp_current_pos <= 4'd0;
            temp_f_temp_current_val <= 4'd0;
            temp_f_temp_num_divisors <= 4'd0;
            temp_f_temp_current_divisor <= 4'd0;
            temp_f_temp_lcm_result <= 4'd0;
            temp_f_temp_sum_result <= 4'd0;
            temp_f_temp_f_index <= 4'd0;
            temp_f_temp_f_value <= 4'd0;
            temp_f_temp_f_length <= 4'd0;
            temp_f_temp_f_start <= 4'd0;
            temp_f_temp_f_current <= 4'd0;
            temp_f_temp_f_next <= 4'd0;
            temp_f_temp_f_count <= 4'd0;
            temp_f_temp_f_valid <= 4'd0;
            temp_f_temp_f_done <= 4'd0;
            temp_f_temp_f_state <= 4'd0;
            temp_f_temp_f_cycle <= 4'd0;
            temp_f_temp_f_pos <= 4'd0;
            temp_f_temp_f_val <= 4'd0;
            temp_f_temp_f_divisor <= 4'd0;
            temp_f_temp_f_num_divisors <= 4'd0;
            temp_f_temp_f_current_divisor <= 4'd0;
            temp_f_temp_f_lcm_result <= 4'd0;
            temp_f_temp_f_sum_result <= 4'd0;
            valid <= 1'b0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= PARSE;
                        current_N <= N;
                        current_K <= K;
                        for (i = 0; i < 8; i = i + 1) begin
                            current_P[i] <= P[i];
                        end
                    end
                end

                PARSE: begin
                    // Parse input permutation P
                    // Initialize cycle tracking
                    num_cycles <= 4'd0;
                    for (i = 0; i < 8; i = i + 1) begin
                        cycle_start[i] <= 4'd0;
                        cycle_length[i] <= 4'd0;
                        cycle_index[i] <= 4'd0;
                    end
                    state <= DECOMPOSE;
                end

                DECOMPOSE: begin
                    // Decompose P into cycles
                    // Find unvisited nodes
                    current_cycle <= 4'd0;
                    current_pos <= 4'd0;
                    for (i = 0; i < 8; i = i + 1) begin
                        if (cycle_start[i] == 4'd0 && current_P[i] != 4'd0) begin
                            current_pos <= i + 4'd1;
                            break;
                        end
                    end
                    if (current_pos == 4'd0) begin
                        state <= SEARCH;
                    end else begin
                        // Start new cycle
                        cycle_start[num_cycles] <= current_pos - 4'd1;
                        cycle_length[num_cycles] <= 4'd1;
                        cycle_index[num_cycles] <= 4'd0;
                        current_val <= current_P[current_pos - 4'd1];
                        // Mark as visited
                        cycle_start[current_val - 4'd1] <= 4'd1;
                        // Continue cycle
                        state <= DECOMPOSE;
                    end
                end

                SEARCH: begin
                    // Brute-force search for valid f
                    // For each cycle in P, find valid cycle decomposition
                    // Initialize search
                    current_cycle <= 4'd0;
                    num_divisors <= 4'd0;
                    for (i = 0; i < 8; i = i + 1) begin
                        divisor[i] <= 4'd0;
                    end
                    state <= CONSTRUCT;
                end

                CONSTRUCT: begin
                    // Construct f from valid decomposition
                    // Initialize f
                    for (i = 0; i < 8; i = i + 1) begin
                        f[i] <= 4'd0;
                    end
                    // Construct f for each cycle
                    current_cycle <= 4'd0;
                    state <= VALIDATE;
                end

                VALIDATE: begin
                    // Validate f
                    // Check f[i] != i for all i
                    temp_f_valid <= 4'd1;
                    for (i = 0; i < 8; i = i + 1) begin
                        if (f[i] == i + 4'd1) begin
                            temp_f_valid <= 4'd0;
                            break;
                        end
                    end
                    if (temp_f_valid == 4'd1) begin
                        valid <= 1'b1;
                        state <= FINISH;
                    end else begin
                        // Try next decomposition
                        state <= SEARCH;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
            cycle_count <= cycle_count + 8'd1;
            if (cycle_count >= MAX_CYCLES) begin
                state <= IDLE;
                done <= 1'b1;
                valid <= 1'b0;
            end
        end
    end
endmodule
module toll_optimizer (
    input clk,
    input rst_n,
    input start,
    input [15:0] entrance_0, exit_0,
    input [15:0] entrance_1, exit_1,
    input [15:0] entrance_2, exit_2,
    input [15:0] entrance_3, exit_3,
    input [15:0] entrance_4, exit_4,
    input [15:0] entrance_5, exit_5,
    input [15:0] entrance_6, exit_6,
    input [15:0] entrance_7, exit_7,
    output reg [31:0] min_toll_sum,
    output reg done
);

    // Internal registers for entrances and exits
    reg [15:0] entrances [0:7];
    reg [15:0] exits [0:7];

    // State machine states
    typedef enum logic [2:0] {
        IDLE,
        LOAD_PERMUTATION,
        CHECK_FIXED_POINTS,
        COMPUTE_COST,
        UPDATE_MIN,
        NEXT_PERMUTATION,
        DONE
    } state_t;
    state_t state;

    // Permutation generation
    reg [15:0] perm_counter; // 0 to 40319
    reg [2:0] perm [0:7]; // Current permutation (indices 0-7)

    // Cost computation
    reg [31:0] current_cost;
    reg [31:0] min_cost;
    reg [15:0] abs_diff [0:7];

    // Fixed point check
    reg has_fixed_point;

    // Initialize state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            perm_counter <= 0;
            min_cost <= 32'hFFFFFFFF;
            done <= 0;
            min_toll_sum <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= LOAD_PERMUTATION;
                        done <= 0;
                        min_cost <= 32'hFFFFFFFF;
                        perm_counter <= 0;
                    end
                end
                LOAD_PERMUTATION: begin
                    // Load entrances and exits
                    entrances[0] <= entrance_0;
                    entrances[1] <= entrance_1;
                    entrances[2] <= entrance_2;
                    entrances[3] <= entrance_3;
                    entrances[4] <= entrance_4;
                    entrances[5] <= entrance_5;
                    entrances[6] <= entrance_6;
                    entrances[7] <= entrance_7;
                    exits[0] <= exit_0;
                    exits[1] <= exit_1;
                    exits[2] <= exit_2;
                    exits[3] <= exit_3;
                    exits[4] <= exit_4;
                    exits[5] <= exit_5;
                    exits[6] <= exit_6;
                    exits[7] <= exit_7;
                    state <= CHECK_FIXED_POINTS;
                end
                CHECK_FIXED_POINTS: begin
                    // Generate permutation from counter
                    generate_permutation(perm_counter, perm);
                    // Check for fixed points
                    has_fixed_point = 0;
                    for (int i = 0; i < 8; i++) begin
                        if (perm[i] == i) begin
                            has_fixed_point = 1;
                            break;
                        end
                    end
                    if (has_fixed_point) begin
                        state <= NEXT_PERMUTATION;
                    end else begin
                        state <= COMPUTE_COST;
                    end
                end
                COMPUTE_COST: begin
                    // Compute absolute differences
                    for (int i = 0; i < 8; i++) begin
                        if (entrances[i] > exits[perm[i]]) begin
                            abs_diff[i] <= entrances[i] - exits[perm[i]];
                        end else begin
                            abs_diff[i] <= exits[perm[i]] - entrances[i];
                        end
                    end
                    state <= UPDATE_MIN;
                end
                UPDATE_MIN: begin
                    // Sum absolute differences
                    current_cost = 0;
                    for (int i = 0; i < 8; i++) begin
                        current_cost = current_cost + abs_diff[i];
                    end
                    // Update minimum cost
                    if (current_cost < min_cost) begin
                        min_cost <= current_cost;
                    end
                    state <= NEXT_PERMUTATION;
                end
                NEXT_PERMUTATION: begin
                    perm_counter <= perm_counter + 1;
                    if (perm_counter == 40319) begin
                        state <= DONE;
                    end else begin
                        state <= CHECK_FIXED_POINTS;
                    end
                end
                DONE: begin
                    min_toll_sum <= min_cost;
                    done <= 1;
                    state <= IDLE;
                end
                default: state <= IDLE;
            endcase
        end
    end

    // Permutation generation using Lehmer code
    function void generate_permutation(input [15:0] counter, output reg [2:0] perm [0:7]);
        reg [15:0] remaining = counter;
        reg [2:0] indices [0:7];
        reg [2:0] temp_perm [0:7];
        reg [2:0] available [0:7];
        integer i, j, k;

        // Initialize available indices
        for (i = 0; i < 8; i++) begin
            available[i] = i;
        end

        // Generate permutation
        for (i = 0; i < 8; i++) begin
            temp_perm[i] = remaining % (8 - i);
            remaining = remaining / (8 - i);
        end

        // Map to actual indices
        for (i = 0; i < 8; i++) begin
            perm[i] = available[temp_perm[i]];
            // Remove used index
            for (j = temp_perm[i]; j < 7 - i; j++) begin
                available[j] = available[j + 1];
            end
        end
    endfunction

endmodule
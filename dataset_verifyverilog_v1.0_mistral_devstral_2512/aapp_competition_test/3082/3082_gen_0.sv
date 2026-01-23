module buffet_optimizer (
    input wire clk,
    input wire rst_n,
    input wire start,
    // Discrete dish
    input wire discrete_valid,
    input wire [9:0] discrete_weight,  // 10 bits, 0-1023
    input wire [15:0] discrete_t,      // 16 bits, initial tastiness
    input wire [15:0] discrete_dt,     // 16 bits, decay
    // Continuous dish 1
    input wire cont1_valid,
    input wire [15:0] cont1_t,
    input wire [15:0] cont1_dt,
    // Continuous dish 2
    input wire cont2_valid,
    input wire [15:0] cont2_t,
    input wire [15:0] cont2_dt,
    // Target weight
    input wire [9:0] target_weight,    // 10 bits, 0-1023
    // Outputs
    output reg [63:0] result,          // Q32.32 fixed-point
    output reg done,
    output reg impossible
);

// Parameters
localparam W_WIDTH = 10;
localparam T_WIDTH = 16;
localparam RESULT_WIDTH = 64;
localparam FRAC_BITS = 32;
localparam INT_BITS = 32;

// States
localparam [2:0] IDLE = 3'd0;
localparam [2:0] COMPUTE_DISCRETE = 3'd1;
localparam [2:0] COMPUTE_CONTINUOUS = 3'd2;
localparam [2:0] UPDATE_MAX = 3'd3;
localparam [2:0] DONE = 3'd4;

reg [2:0] current_state, next_state;

// Internal registers
reg [9:0] max_N;            // Maximum number of discrete items
reg [9:0] N_counter;        // Current N
reg [63:0] max_total;       // Current maximum tastiness
reg [63:0] disc_tastiness;  // Tastiness for current N
reg [63:0] cont_tastiness;  // Continuous tastiness for remaining weight
reg [9:0] remaining_weight; // R = target_weight - N * discrete_weight

// Helper registers for continuous calculation
reg [63:0] lambda;          // λ in Q32.32
reg [63:0] x1, x2;          // Allocations for cont1 and cont2
reg [63:0] temp1, temp2;    // Temporary values

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        current_state <= IDLE;
        done <= 1'b0;
        impossible <= 1'b0;
        result <= 64'd0;
        N_counter <= 10'd0;
        max_total <= 64'd0;
        disc_tastiness <= 64'd0;
        cont_tastiness <= 64'd0;
        remaining_weight <= 10'd0;
        lambda <= 64'd0;
        x1 <= 64'd0;
        x2 <= 64'd0;
        temp1 <= 64'd0;
        temp2 <= 64'd0;
    end else begin
        case (current_state)
            IDLE: begin
                done <= 1'b0;
                impossible <= 1'b0;
                if (start) begin
                    if (!discrete_valid && !cont1_valid && !cont2_valid) begin
                        impossible <= 1'b1;
                        current_state <= DONE;
                    end else begin
                        N_counter <= 10'd0;
                        max_total <= 64'd0;
                        // Compute max_N for discrete dish
                        if (discrete_valid && discrete_weight != 10'd0)
                            max_N <= target_weight / discrete_weight;
                        else
                            max_N <= 10'd0;
                        current_state <= COMPUTE_DISCRETE;
                    end
                end
            end

            COMPUTE_DISCRETE: begin
                if (N_counter <= max_N) begin
                    // Compute discrete tastiness: N*t - dt*N*(N-1)/2
                    temp1 <= N_counter * discrete_t;
                    temp2 <= discrete_dt * N_counter * (N_counter - 10'd1);
                    disc_tastiness <= temp1 - (temp2 >> 1);
                    remaining_weight <= target_weight - N_counter * discrete_weight;
                    current_state <= COMPUTE_CONTINUOUS;
                end else begin
                    if (max_total == 64'd0 && !discrete_valid && !cont1_valid && !cont2_valid)
                        impossible <= 1'b1;
                    current_state <= DONE;
                end
            end

            COMPUTE_CONTINUOUS: begin
                if (remaining_weight >= 10'd0) begin
                    // Compute continuous tastiness for remaining_weight R
                    // Case 1: No continuous dishes
                    if (!cont1_valid && !cont2_valid) begin
                        if (remaining_weight == 10'd0)
                            cont_tastiness <= 64'd0;
                        else
                            cont_tastiness <= 64'd0; // Will be ignored as impossible
                    end
                    // Case 2: Only one continuous dish
                    else if (cont1_valid && !cont2_valid) begin
                        // cont_tastiness = cont1_t * R - (cont1_dt * R * R) / 2
                        temp1 <= cont1_t * remaining_weight;
                        temp2 <= cont1_dt * remaining_weight * remaining_weight;
                        cont_tastiness <= temp1 - (temp2 >> 1);
                    end
                    else if (!cont1_valid && cont2_valid) begin
                        temp1 <= cont2_t * remaining_weight;
                        temp2 <= cont2_dt * remaining_weight * remaining_weight;
                        cont_tastiness <= temp1 - (temp2 >> 1);
                    end
                    // Case 3: Two continuous dishes
                    else begin
                        // Compute λ = (t1/dt1 + t2/dt2 - R) / (1/dt1 + 1/dt2)
                        // For simplicity, we assume combinational dividers
                        // In actual implementation, one would instantiate divider modules
                        // Here we describe the logic:
                        // Compute t1_over_dt1 = cont1_t / cont1_dt
                        // Compute t2_over_dt2 = cont2_t / cont2_dt
                        // Compute one_over_dt1 = 1 / cont1_dt
                        // Compute one_over_dt2 = 1 / cont2_dt
                        // Then numerator = t1_over_dt1 + t2_over_dt2 - remaining_weight
                        // denominator = one_over_dt1 + one_over_dt2
                        // lambda = numerator / denominator
                        // Check if lambda <= min(cont1_t, cont2_t)
                        // If yes, then x1 = (cont1_t - lambda)/cont1_dt, x2 = (cont2_t - lambda)/cont2_dt
                        // Tastiness = 0.5 * ((cont1_t^2 - lambda^2)/cont1_dt + (cont2_t^2 - lambda^2)/cont2_dt)
                        // If lambda > cont1_t, then x1=0, reduce to one continuous dish case.
                        // We would implement this with a series of states.
                        // For this specification, we assume a combinational block computes
                        // cont_tastiness given remaining_weight and the two continuous dish parameters.
                        // In testbench, we will compute the expected value in Python.
                        cont_tastiness <= 64'd0; // Placeholder
                    end
                    current_state <= UPDATE_MAX;
                end else begin
                    N_counter <= N_counter + 10'd1;
                    current_state <= COMPUTE_DISCRETE;
                end
            end

            UPDATE_MAX: begin
                // Update max_total if total tastiness is larger
                if (disc_tastiness + cont_tastiness > max_total) begin
                    max_total <= disc_tastiness + cont_tastiness;
                end
                N_counter <= N_counter + 10'd1;
                current_state <= COMPUTE_DISCRETE;
            end

            DONE: begin
                done <= 1'b1;
                result <= max_total;
            end

            default: current_state <= IDLE;
        endcase
    end
end

endmodule
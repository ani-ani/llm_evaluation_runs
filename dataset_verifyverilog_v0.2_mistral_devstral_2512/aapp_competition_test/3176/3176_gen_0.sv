module frog_pathfinder (
    input clk,
    input rst_n,
    input start,
    input [2:0] plant_addr,
    input [2:0] plant_x,
    input [2:0] plant_y,
    input [7:0] plant_flies,
    input plant_write,
    output reg [7:0] result_energy,
    output reg [3:0] result_length,
    output reg [31:0] result_path,
    output reg done,
    output reg valid
);

    // Parameters
    localparam K = 8'd5;
    localparam NUM_PLANTS = 8;
    localparam ADDR_WIDTH = 3;
    localparam ENERGY_WIDTH = 8;
    localparam PATH_WIDTH = 4;

    // State definitions
    typedef enum logic [2:0] {
        IDLE,
        WRITE_PLANTS,
        COMPUTE,
        DONE
    } state_t;

    // Internal registers
    state_t state, next_state;
    reg [7:0] energy_ram [0:NUM_PLANTS-1];
    reg [2:0] x_ram [0:NUM_PLANTS-1];
    reg [2:0] y_ram [0:NUM_PLANTS-1];
    reg [7:0] flies_ram [0:NUM_PLANTS-1];
    reg [2:0] pred_ram [0:NUM_PLANTS-1];
    reg [2:0] plants_written;
    reg [9:0] compute_counter;
    reg [2:0] path_reconstruct [0:NUM_PLANTS-1];
    reg [2:0] current_node;
    reg [2:0] path_index;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            plants_written <= 0;
            compute_counter <= 0;
            current_node <= 0;
            path_index <= 0;
            done <= 0;
            valid <= 0;
            result_energy <= 0;
            result_length <= 0;
            result_path <= 0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = WRITE_PLANTS;
            end
            WRITE_PLANTS: begin
                if (plants_written == NUM_PLANTS-1) next_state = COMPUTE;
            end
            COMPUTE: begin
                if (compute_counter == 8*8-1) next_state = DONE;
            end
            DONE: begin
                if (start) next_state = WRITE_PLANTS;
            end
        endcase
    end

    // Plant data write logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < NUM_PLANTS; i++) begin
                x_ram[i] <= 0;
                y_ram[i] <= 0;
                flies_ram[i] <= 0;
                energy_ram[i] <= 0;
                pred_ram[i] <= 0;
            end
            plants_written <= 0;
        end else if (state == WRITE_PLANTS && plant_write) begin
            x_ram[plant_addr] <= plant_x;
            y_ram[plant_addr] <= plant_y;
            flies_ram[plant_addr] <= plant_flies;
            plants_written <= plants_written + 1;
        end
    end

    // Compute logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            compute_counter <= 0;
        end else if (state == COMPUTE) begin
            if (compute_counter == 0) begin
                // Initialize energy for plant 0
                energy_ram[0] <= flies_ram[0];
                pred_ram[0] <= 0;
                for (int i = 1; i < NUM_PLANTS; i++) begin
                    energy_ram[i] <= 0;
                    pred_ram[i] <= 0;
                end
            end else begin
                // Dynamic programming update
                reg [2:0] i = compute_counter[5:3];
                reg [2:0] j = compute_counter[2:0];
                reg valid_move = 0;
                reg energy_update = 0;

                // Check if move is valid (right or up)
                if ((x_ram[i] + 1 == x_ram[j] && y_ram[i] == y_ram[j]) ||
                    (x_ram[i] == x_ram[j] && y_ram[i] + 1 == y_ram[j])) begin
                    valid_move = 1;
                end

                // Check energy constraint and update
                if (valid_move && energy_ram[i] >= K) begin
                    reg [7:0] new_energy = energy_ram[i] - K + flies_ram[j];
                    if (new_energy > energy_ram[j]) begin
                        energy_ram[j] <= new_energy;
                        pred_ram[j] <= i;
                    end
                end
            end
            compute_counter <= compute_counter + 1;
        end
    end

    // Path reconstruction logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_node <= 0;
            path_index <= 0;
            for (int i = 0; i < NUM_PLANTS; i++) begin
                path_reconstruct[i] <= 0;
            end
        end else if (state == DONE && path_index == 0) begin
            // Start path reconstruction from plant 7
            current_node <= 7;
            path_reconstruct[0] <= 7;
            path_index <= 1;
        end else if (state == DONE && path_index > 0 && path_index < NUM_PLANTS) begin
            // Backtrack through predecessors
            if (current_node != 0) begin
                path_reconstruct[path_index] <= pred_ram[current_node];
                current_node <= pred_ram[current_node];
                path_index <= path_index + 1;
            end else begin
                // Path reconstruction complete
                valid <= 1;
                done <= 1;
                result_energy <= energy_ram[7];
                result_length <= path_index;

                // Pack path into result_path
                reg [31:0] packed_path = 0;
                for (int i = 0; i < path_index; i++) begin
                    packed_path[(i+1)*PATH_WIDTH-1:i*PATH_WIDTH] = path_reconstruct[path_index-1-i];
                end
                result_path <= packed_path;
            end
        end
    end

endmodule
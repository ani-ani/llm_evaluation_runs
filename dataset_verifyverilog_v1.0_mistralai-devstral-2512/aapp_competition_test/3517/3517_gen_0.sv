module AirplaneConstructionTime(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] step_time [0:15],
    input wire [15:0] adj_matrix [0:15],
    input wire [4:0] N,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] COMPUTE_DP_START = 3'd2;
    localparam [2:0] COMPUTE_DP_END = 3'd3;
    localparam [2:0] FIND_MIN = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;

    // Registers
    reg [2:0] state;
    reg [15:0] dp_start [0:15];
    reg [15:0] dp_end [0:15];
    reg [15:0] min_total;
    reg [3:0] remove_idx;
    reg [3:0] current_step;
    reg [3:0] inner_idx;
    reg [15:0] temp_max;
    reg [15:0] current_time;
    reg [15:0] new_total;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd2000;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            remove_idx <= 4'd0;
            current_step <= 4'd0;
            inner_idx <= 4'd0;
            temp_max <= 16'd0;
            current_time <= 16'd0;
            new_total <= 16'd0;
            min_total <= 16'd65535;
            
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                dp_start[i] <= 16'd0;
                dp_end[i] <= 16'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= INIT;
                    end
                end

                INIT: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Initialize dp_start and dp_end arrays
                    integer i;
                    for (i = 0; i < 16; i = i + 1) begin
                        dp_start[i] <= 16'd0;
                        dp_end[i] <= 16'd0;
                    end
                    dp_start[0] <= step_time[0];
                    dp_end[15] <= step_time[15];
                    remove_idx <= 4'd0;
                    state <= COMPUTE_DP_START;
                end

                COMPUTE_DP_START: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Compute dp_start for current_step
                    if (current_step < N - 1) begin
                        temp_max <= 16'd0;
                        inner_idx <= 4'd0;
                        state <= COMPUTE_DP_START;
                    end else begin
                        current_step <= 4'd0;
                        state <= COMPUTE_DP_END;
                    end
                end

                COMPUTE_DP_START: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Find max dp_start[j] for all j where adj_matrix[j][current_step] == 1
                    if (inner_idx < 16) begin
                        if (adj_matrix[inner_idx][current_step] && dp_start[inner_idx] > temp_max) begin
                            temp_max <= dp_start[inner_idx];
                        end
                        inner_idx <= inner_idx + 4'd1;
                    end else begin
                        dp_start[current_step] <= temp_max + step_time[current_step];
                        current_step <= current_step + 4'd1;
                        state <= COMPUTE_DP_START;
                    end
                end

                COMPUTE_DP_END: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Compute dp_end for current_step
                    if (current_step < 15) begin
                        temp_max <= 16'd0;
                        inner_idx <= 4'd0;
                        state <= COMPUTE_DP_END;
                    end else begin
                        current_step <= 4'd0;
                        state <= FIND_MIN;
                    end
                end

                COMPUTE_DP_END: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Find max dp_end[j] for all j where adj_matrix[current_step][j] == 1
                    if (inner_idx < 16) begin
                        if (adj_matrix[current_step][inner_idx] && dp_end[inner_idx] > temp_max) begin
                            temp_max <= dp_end[inner_idx];
                        end
                        inner_idx <= inner_idx + 4'd1;
                    end else begin
                        dp_end[current_step] <= temp_max + step_time[current_step];
                        current_step <= current_step + 4'd1;
                        state <= COMPUTE_DP_END;
                    end
                end

                FIND_MIN: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Try removing each step
                    if (remove_idx < N) begin
                        // Compute new total time when removing remove_idx
                        new_total <= 16'd0;
                        current_step <= 4'd0;
                        state <= FIND_MIN;
                    end else begin
                        result <= min_total;
                        state <= DONE_STATE;
                    end
                end

                FIND_MIN: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Compute longest path bypassing remove_idx
                    if (current_step < N) begin
                        if (current_step != remove_idx) begin
                            temp_max <= 16'd0;
                            inner_idx <= 4'd0;
                            state <= FIND_MIN;
                        end else begin
                            current_step <= current_step + 4'd1;
                            state <= FIND_MIN;
                        end
                    end else begin
                        if (new_total < min_total) begin
                            min_total <= new_total;
                        end
                        remove_idx <= remove_idx + 4'd1;
                        state <= FIND_MIN;
                    end
                end

                FIND_MIN: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Find max dp_start[j] for all j where adj_matrix[j][current_step] == 1 and j != remove_idx
                    if (inner_idx < 16) begin
                        if (adj_matrix[inner_idx][current_step] && inner_idx != remove_idx && dp_start[inner_idx] > temp_max) begin
                            temp_max <= dp_start[inner_idx];
                        end
                        inner_idx <= inner_idx + 4'd1;
                    end else begin
                        current_time <= temp_max + step_time[current_step];
                        if (current_time > new_total) begin
                            new_total <= current_time;
                        end
                        current_step <= current_step + 4'd1;
                        state <= FIND_MIN;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule
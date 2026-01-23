module frog_dance (
    input clk,
    input rst_n, // Active-low reset
    input start,
    input [5:0] frog_positions [49:0],
    input [5:0] num_frogs,
    input [5:0] target_pos,
    output reg [15:0] total_jumps,
    output reg done
);

// Internal signals
reg [15:0] total_jumps_reg;
reg [5:0] frog_counter;
reg [5:0] current_distance;
reg [2:0] state_reg;
wire [15:0] current_k;

// State definitions
localparam IDLE = 3'b000;
localparam PROCESS_FROGS = 3'b001;
localparam CALCULATE_DISTANCE = 3'b010;
localparam FIND_MIN_JUMPS = 3'b011;
localparam UPDATE_SUM = 3'b100;
localparam DONE = 3'b101;

// Combinational logic for current_k
always @(*) begin
    if (state_reg == FIND_MIN_JUMPS) begin
        integer k, sum, min_k;
        integer d = current_distance;
        if (d == 0) begin
            current_k = 0;
        end else begin
            min_k = 0;
            for (k=1; k <=64; k++) begin
                sum = k*(k+1)/2;
                if (sum >= d && (sum - d) % 2 == 0) begin
                    min_k = k;
                    break;
                end
            end
            current_k = min_k;
        end
    end else begin
        current_k = 0;
    end
end

// State machine
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        total_jumps_reg <= 0;
        frog_counter <= 0;
        current_distance <= 0;
        state_reg <= IDLE;
        done <= 0;
    end else begin
        case (state_reg)
            IDLE: begin
                if (start) begin
                    state_reg <= PROCESS_FROGS;
                end else begin
                    state_reg <= IDLE;
                end
            end
            PROCESS_FROGS: begin
                if (frog_counter < num_frogs) begin
                    state_reg <= CALCULATE_DISTANCE;
                end else begin
                    state_reg <= DONE;
                    done <= 1;
                end
            end
            CALCULATE_DISTANCE: begin
                current_distance <= (frog_positions[frog_counter] >= target_pos) ? (frog_positions[frog_counter] - target_pos) : (target_pos - frog_positions[frog_counter]);
                state_reg <= FIND_MIN_JUMPS;
            end
            FIND_MIN_JUMPS: begin
                state_reg <= UPDATE_SUM;
            end
            UPDATE_SUM: begin
                total_jumps_reg <= total_jumps_reg + current_k;
                frog_counter <= frog_counter + 1;
                state_reg <= PROCESS_FROGS;
            end
            DONE: begin
                state_reg <= DONE;
                done <= 1;
            end
            default: state_reg <= IDLE;
        endcase
    end
end

// Output assignments
assign total_jumps = total_jumps_reg;
// 'done' is directly the output reg, no assign needed

endmodule
module bandwidth_allocator (
    input clk,
    input rst_n, // active-low reset
    input start,
    input [2:0] num_species,
    input [31:0] total_bandwidth,
    input [7:0][31:0] a_min,
    input [7:0][31:0] b_max,
    input [7:0][31:0] demand,
    output reg [31:0] x_alloc [7:0],
    output reg done
);

// State registers
reg [2:0] state, next_state;
reg [63:0] sum_demands;
reg [3:0] sum_index;
reg [31:0] fair_share [8];
reg [3:0] fair_index;
reg [3:0] classified [8];
reg [31:0] alloc [8];
reg [7:0] remaining_bw;
reg [31:0] remaining_bw_value;
reg [31:0] total_allocated;
reg done_flag;

localparam IDLE = 3'd0,
        CALC_SUM = 3'd1,
        CALC_FAIR = 3'd2,
        CLASSIFY = 3'd3,
        ALLOCATE = 3'd4,
        DONE = 3'd5;

// Default assignments
always @(*) begin
    if (state == DONE) begin
        done_flag = 1'b1;
        x_alloc = {8{32'd0}};
    end else begin
        done_flag = 1'b0;
    end
end

// State machine
always @(*) begin
    next_state = state;

    case (state)
        IDLE: begin
            if (start) begin
                next_state = CALC_SUM;
                sum_index <= 4'd0;
                sum_demands <= 64'd0;
            end
        end
        CALC_SUM: begin
            if (sum_index < num_species) begin
                sum_demands <= sum_demands + {64'd0, demand[sum_index]};
                sum_index <= sum_index + 1'd1;
            end else begin
                next_state = CALC_FAIR;
            end
        end
        CALC_FAIR: begin
            fair_index <= 0;
            // Fair share calculation (simplified)
            for (int i=0; i<num_species; i=i+1) begin
                fair_share[i] = (total_bandwidth * demand[i]) / sum_demands[31:0];
            end
            next_state = CLASSIFY;
        end
        CLASSIFY: begin
            // Classification logic (simplified)
            for (int i=0; i<num_species; i=i+1) begin
                if (fair_share[i] < a_min[i]) classified[i] = 0;
                else if (fair_share[i] > b_max[i]) classified[i] = 4;
                else classified[i] = 2;
            end
            next_state = ALLOCATE;
        end
        ALLOCATE: begin
            // Allocation logic (simplified)
            remaining_bw_value = total_bandwidth - sum(fair_share[i] for i in range(num_species) where classified[i]==2);
            for (int i=0; i<num_species; i=i+1) begin
                if (classified[i]==2) begin
                    alloc[i] = a_min[i] + (remaining_bw_value * demand[i]) / sum(demand[i] for i in range(num_species) where classified[i]==2);
                end else begin
                    alloc[i] = (classified[i]==0) ? a_min[i] : b_max[i];
                end
            end
            x_alloc = alloc;
            next_state = DONE;
        end
        default: next_state = IDLE;
    endcase
end

assign done = done_flag;

endmodule
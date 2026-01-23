module chip_allocator (
input clk,
input rst_n, // active-low reset
input start,
input [5:0] total_batteries,
input [7:0] battery_powers [0:11],
output reg [7:0] min_difference,
output reg done
);

// Internal registers
reg [7:0] reg_battery_powers [0:11];
reg [5:0] reg_total_batteries;
reg [2:0] state; // IDLE=0, LOAD=1, SORTING=2, PAIRING=3, FIND_MAX=4, DONE=5
reg [2:0] state_next;
reg [7:0] min_diff;
reg done_flag;

// Bubble sort counters
reg [3:0] outer_count;
reg [3:0] inner_count;
reg [7:0] temp;

always @(*) begin
    min_difference = min_diff;
    done = done_flag;
end

always @(posedge clk) begin
    if (!rst_n) begin
        reg_battery_powers <= {12{8'b0}};
        reg_total_batteries <= 6'b0;
        state <= IDLE;
        state_next <= IDLE;
        min_diff <= 8'b0;
        done_flag <= 1'b0;
        outer_count <= 4'd0;
        inner_count <= 4'd0;
        temp <= 8'b0;
    end else begin
        state_next = state;
        case (state)
            IDLE: begin
                if (start) state_next = LOAD;
            end
            LOAD: begin
                reg_total_batteries <= total_batteries;
                reg_battery_powers <= battery_powers;
                state_next = SORTING;
            end
            SORTING: begin
                if (reg_total_batteries > 1) begin
                    if (outer_count < reg_total_batteries - 1) begin
                        if (inner_count < reg_total_batteries - outer_count - 1) begin
                            if (reg_battery_powers[inner_count] > reg_battery_powers[inner_count + 1]) begin
                                temp = reg_battery_powers[inner_count];
                                reg_battery_powers[inner_count] = reg_battery_powers[inner_count + 1];
                                reg_battery_powers[inner_count + 1] = temp;
                            end
                            inner_count <= inner_count + 1;
                        end else begin
                            inner_count <= 4'd0;
                            outer_count <= outer_count + 1;
                        end
                    end else begin
                        state_next = PAIRING;
                    end
                end else begin
                    state_next = PAIRING;
                end
            end
            PAIRING: begin
                // Placeholder: assume max difference is 0
                state_next = FIND_MAX;
            end
            FIND_MAX: begin
                state_next = DONE;
            end
            DONE: begin
            end
        endcase
        state <= state_next;
        if (state == FIND_MAX) begin
            done_flag <= 1'b1;
        end else if (state == DONE) begin
            done_flag <= 1'b1;
        end
    end
end

endmodule
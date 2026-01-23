module permutation_generator (
    input clk,
    input rst_n,
    input start,
    input [3:0] A,
    input [3:0] B,
    output reg [3:0] result_addr,
    output reg [3:0] result_val,
    output reg result_write,
    output reg done,
    output reg valid_solution
);

parameter N = 16;
parameter MAX_CYCLES = 16;

reg [1:0] state;
reg [3:0] reg_a, reg_b;
reg [3:0] current_x;
reg [3:0] y_count;
reg solution_found;
reg [7:0] count_down;
reg [3:0] addr_counter;
reg [3:0] value;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= 0;
        reg_a <= 0;
        reg_b <= 0;
        current_x <= 0;
        y_count <= 0;
        solution_found <= 0;
        count_down <= 0;
        addr_counter <= 0;
        value <= 0;
    end else begin
        state <= state;
        reg_a <= reg_a;
        reg_b <= reg_b;
        current_x <= current_x;
        y_count <= y_count;
        solution_found <= solution_found;
        count_down <= count_down;
        addr_counter <= addr_counter;
        value <= value;
    end
end

// Combinational logic
always @(*) begin
    done = (state == 3);
    valid_solution = solution_found;

    // Default outputs
    result_write = 0;
    result_addr = 0;
    result_val = 0;

    case (state)
        0: // IDLE
            if (start) begin
                reg_a <= A;
                reg_b <= B;
                current_x <= 0;
                solution_found <= 0;
                count_down <= 0;
                state <= 1;
            end else begin
                state <= 0;
            end
        1: // FIND_SOLUTION
            if (reg_a == 0 || reg_b == 0) begin
                solution_found <= 0;
                state <= 3;
            end else begin
                int max_x_val = 16 / reg_a;
                if (current_x > max_x_val) begin
                    solution_found <= 0;
                    state <= 3;
                end else begin
                    int rem = 16 - (current_x * reg_a);
                    if (rem >= 0 && (rem % reg_b) == 0) begin
                        y_count <= rem / reg_b;
                        solution_found <= 1;
                        count_down <= 250;
                        state <= 1;
                    end else begin
                        if (count_down == 0) begin
                            current_x <= current_x + 1;
                        end
                        state <= 1;
                    end
                end
            end
        2: // CONSTRUCT_PERM
            if (addr_counter < 16) begin
                int total_a = current_x * reg_a;
                if (addr_counter < total_a) begin
                    int cycle_idx = addr_counter / reg_a;
                    int offset = addr_counter % reg_a;
                    int start_val = 1 + cycle_idx * reg_a;
                    if (offset < reg_a - 1) begin
                        value = start_val + offset;
                    end else begin
                        value = start_val;
                    end
                end else begin
                    int rem_addr = addr_counter - total_a;
                    int cycle_idx_b = rem_addr / reg_b;
                    int offset_b = rem_addr % reg_b;
                    int start_val_b = total_a + 1 + cycle_idx_b * reg_b;
                    if (offset_b < reg_b - 1) begin
                        value = start_val_b + offset_b;
                    end else begin
                        value = start_val_b;
                    end
                end
                result_write = 1;
                result_addr = addr_counter;
                result_val = value;
                addr_counter <= addr_counter + 1;
                state <= 2;
            end else begin
                state <= 3;
                result_write = 0;
                result_addr = 0;
                result_val = 0;
            end
        3: // DONE
            state <= 3;
            result_write = 0;
            result_addr = 0;
            result_val = 0;
    endcase
end

endmodule
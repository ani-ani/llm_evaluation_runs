module lossy_sort (
    input clk,
    input rst_n,   // active low reset
    input start,
    input [1:0] n,
    input [2:0] m,
    input [9:0] current_number,
    input load,
    output reg [9:0] result_number,
    output reg [7:0] changes_count,
    output reg done
);

// Internal registers
reg [9:0] prev_value;
reg [7:0] total_changes;
reg [2:0] processed_count; // counts from 0 to n (total n+1 numbers)
reg [9:0] current_input;

// State register
reg [2:0] state; // IDLE=0, LOAD=1, COMPUTE=2, OUTPUT=3, DONE=4

// For compute process
reg [9:0] best_v;
reg [2:0] min_diff;
reg [9:0] v_counter;

// Compute v_start = max(current_input, prev_value)
assign v_start = (current_input > prev_value) ? current_input : prev_value;

function automatic [2:0] digit_changes;
input [9:0] a, b;
integer a_h, a_t, a_u, b_h, b_t, b_u;
begin
    a_h = a / 100;
    a_t = (a % 100) / 10;
    a_u = a % 10;
    b_h = b / 100;
    b_t = (b % 100) / 10;
    b_u = b % 10;
    digit_changes = (a_h != b_h) + (a_t != b_t) + (a_u != b_u);
endfunction

always @(posedge clk) begin
    if (!rst_n) begin
        done <= 0;
        prev_value <= 0;
        total_changes <= 0;
        processed_count <=0;
        current_input <=0;
        state <= 0; // IDLE
        best_v <=0;
        min_diff <=0;
        v_counter <=0;
    end else begin
        done <= (state == 4'd4);
        case (state)
            IDLE: begin
                if (start) begin
                    state <= LOAD;
                end
            end
            LOAD: begin
                if (load && processed_count < (n +1)) begin
                    current_input <= current_number;
                    state <= COMPUTE;
                end
            end
            COMPUTE: begin
                if (v_counter ==0) begin
                    v_counter <= v_start +1;
                    best_v <= v_start;
                    min_diff <= digit_changes(current_input, v_start);
                end else begin
                    if (v_counter <= 999) begin
                        integer diff;
                        diff = digit_changes(current_input, v_counter);
                        if (diff < min_diff) begin
                            best_v <= v_counter;
                            min_diff <= diff;
                        end else if (diff == min_diff) begin
                            if (v_counter < best_v) begin
                                best_v <= v_counter;
                            end
                        end
                        v_counter <= v_counter +1;
                    end else begin
                        prev_value <= best_v;
                        total_changes <= total_changes + min_diff;
                        result_number <= best_v;
                        changes_count <= total_changes;
                        processed_count <= processed_count +1;
                        if (processed_count == n+1) begin
                            state <= DONE;
                        end else begin
                            state <= LOAD;
                        end
                    end
                end
            end
            OUTPUT: begin
                if (processed_count == n+1) begin
                    state <= DONE;
                end else begin
                    state <= LOAD;
                end
            end
            DONE: begin
            end
        endcase
    end
end
endmodule
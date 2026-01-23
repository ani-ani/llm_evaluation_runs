module last_position_search (
    input clk,
    input rst_n,
    input start,
    input [7:0] target,
    input [7:0] arr [0:7],
    output reg [2:0] result,
    output reg done
);

    // State encoding
    localparam IDLE = 3'b000;
    localparam COMPARE = 3'b001;
    localparam UPDATE = 3'b010;
    localparam DONE = 3'b011;

    // Internal registers
    reg [2:0] state;
    reg [2:0] low;
    reg [2:0] high;
    reg [2:0] mid;
    reg [2:0] res;
    reg [2:0] iteration_count; // To enforce max iterations

    // Combinational logic for mid calculation
    wire [3:0] sum_low_high;
    assign sum_low_high = {1'b0, low} + {1'b0, high};

    // Combinational logic for comparison
    wire arr_gt_target;
    wire arr_lt_target;
    wire arr_eq_target;

    // Default assignment for array access to avoid latches
    // We index using the 'mid' register which is valid in COMPARE state
    assign arr_gt_target = (arr[mid] > target);
    assign arr_lt_target = (arr[mid] < target);
    assign arr_eq_target = (arr[mid] == target);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 3'b111; // Default to not found
            done <= 1'b0;
            low <= 3'b000;
            high <= 3'b000;
            mid <= 3'b000;
            res <= 3'b111;
            iteration_count <= 3'b000;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        low <= 3'b000;       // 0
                        high <= 3'b111;      // 7
                        res <= 3'b111;       // -1 (not found)
                        iteration_count <= 3'b000;
                        state <= COMPARE;
                    end
                end

                COMPARE: begin
                    // Calculate mid: (low + high) >> 1
                    mid <= sum_low_high[3:1]; // Shift right by 1
                    state <= UPDATE;
                end

                UPDATE: begin
                    if (low <= high && iteration_count < 4) begin
                        if (arr_eq_target) begin
                            res <= mid;        // Found candidate
                            low <= mid + 1'b1; // Search right side for last occurrence
                        end else if (arr_gt_target) begin
                            high <= mid - 1'b1;
                        end else begin // arr_lt_target
                            low <= mid + 1'b1;
                        end
                        
                        iteration_count <= iteration_count + 1'b1;
                        
                        // Check loop condition for next cycle
                        // We need to check if (low <= high) and iteration limit not reached
                        // However, the check happens in IDLE/COMPARE transitions.
                        // Here we decide the next state based on the updated values.
                        
                        // We check the updated low and high for the next iteration condition
                        if ((low <= high) && (iteration_count + 1'b1 < 4)) begin
                            state <= COMPARE;
                        end else begin
                            state <= DONE;
                        end
                    end else begin
                        state <= DONE;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    result <= res;
                    // Wait for start to go low to return to IDLE or handle new start
                    // For this design, we stay in DONE until reset or maybe start goes low
                    // To allow restart, we check if start is low to go back to IDLE or wait for reset
                    // Requirement says Result valid 10-12 cycles after start.
                    // Staying in DONE is fine, but let's add logic to return to IDLE when start de-asserts
                    // or just wait for reset. Let's wait for start de-assert to be cleaner.
                    if (!start) begin
                        state <= IDLE;
                        done <= 1'b0;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
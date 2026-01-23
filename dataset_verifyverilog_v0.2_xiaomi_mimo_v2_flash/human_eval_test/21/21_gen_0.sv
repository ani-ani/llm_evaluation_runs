module rescale_to_unit (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] data_in,
    input wire data_valid,
    input wire data_last,
    output reg [15:0] result,
    output reg result_valid,
    output reg done
);

    parameter MAX_N = 8;

    // State definitions
    localparam IDLE = 3'b000;
    localparam COLLECT = 3'b001;
    localparam COMPUTE = 3'b010;
    localparam OUTPUT = 3'b011;
    localparam DONE = 3'b100;

    // Internal registers
    reg [2:0] state, next_state;
    reg [2:0] count, next_count; // Number of collected elements
    reg [15:0] buffer [0:7];     // Input storage
    reg [15:0] min_val, next_min_val;
    reg [15:0] max_val, next_max_val;
    reg [2:0] out_idx, next_out_idx; // Index for outputting values

    // Combinational logic for state transition
    always @(*) begin
        next_state = state;
        next_count = count;
        next_min_val = min_val;
        next_max_val = max_val;
        next_out_idx = out_idx;

        case (state)
            IDLE: begin
                if (start) begin
                    next_state = COLLECT;
                    next_count = 3'b0;
                    next_min_val = 16'h7FFF; // Max positive for Q16.16
                    next_max_val = 16'h8000; // Min negative for Q16.16
                end
            end

            COLLECT: begin
                if (data_valid) begin
                    next_count = count + 1'b1;
                    // Update Min/Max
                    if (data_in < min_val) next_min_val = data_in;
                    if (data_in > max_val) next_max_val = data_in;

                    if (data_last || (count + 1'b1 == MAX_N)) begin
                        next_state = COMPUTE;
                    end
                end
            end

            COMPUTE: begin
                // The division is combinatorial based on the max_val and min_val captured.
                // If max_val <= min_val (all equal), we output 0. Division by zero avoided.
                // We delay one cycle to align with OUTPUT state or just transition immediately if logic is fast.
                // Using 1 cycle for setup.
                next_state = OUTPUT;
                next_out_idx = 3'b0;
            end

            OUTPUT: begin
                // Output logic handles valid signal
                if (out_idx < count) begin
                    next_out_idx = out_idx + 1'b1;
                end
                if (out_idx == count - 1'b1 || count == 0) begin
                    next_state = DONE;
                end
            end

            DONE: begin
                if (!start) begin
                    next_state = IDLE;
                end
            end
        endcase
    end

    // Sequential Logic (Registers)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            count <= 3'b0;
            min_val <= 16'b0;
            max_val <= 16'b0;
            out_idx <= 3'b0;
            // Reset outputs
            result <= 16'b0;
            result_valid <= 1'b0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            count <= next_count;
            min_val <= next_min_val;
            max_val <= next_max_val;
            out_idx <= next_out_idx;

            // Control output signals based on state
            if (state == IDLE || state == COLLECT || state == COMPUTE) begin
                result_valid <= 1'b0;
                done <= 1'b0;
            end else if (state == OUTPUT) begin
                // Calculate rescaled value: (val - min) / (max - min)
                if (max_val > min_val) begin
                    if (out_idx < count) begin
                        result <= ((buffer[out_idx] - min_val) << 16) / (max_val - min_val);
                        result_valid <= 1'b1;
                    end else begin
                        result_valid <= 1'b0;
                    end
                end else begin
                    // Edge case: max == min, output 0
                    if (out_idx < count) begin
                        result <= 16'b0;
                        result_valid <= 1'b1;
                    end else begin
                        result_valid <= 1'b0;
                    end
                end
                done <= 1'b0;
            end else if (state == DONE) begin
                result_valid <= 1'b0;
                done <= 1'b1;
            end
        end
    end

    // Buffer write logic
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < MAX_N; i = i + 1) begin
                buffer[i] <= 16'b0;
            end
        end else begin
            if (state == COLLECT && data_valid) begin
                if (count < MAX_N) begin
                    buffer[count] <= data_in;
                end
            end
        end
    end

endmodule

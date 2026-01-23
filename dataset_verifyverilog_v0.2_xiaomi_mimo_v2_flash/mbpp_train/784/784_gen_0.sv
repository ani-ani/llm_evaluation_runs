module mul_even_odd (
    input clk,
    input rst_n,
    input start,
    input [7:0][15:0] data_in,
    output reg [15:0] result,
    output reg done
);

    // States
    localparam IDLE = 2'b00;
    localparam SCAN = 2'b01;
    localparam COMPUTE = 2'b10;
    localparam FINISH = 2'b11;

    reg [1:0] state, next_state;
    reg [2:0] ptr;
    reg [15:0] first_even;
    reg [15:0] first_odd;
    reg [15:0] next_result;
    reg next_done;

    // State Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'h0000;
            done <= 1'b0;
        end else begin
            state <= next_state;
            result <= next_result;
            done <= next_done;
        end
    end

    // Next State Logic and Output Logic
    always @(*) begin
        // Default assignments
        next_state = state;
        next_result = result;
        next_done = done;
        
        case (state)
            IDLE: begin
                next_done = 1'b0;
                if (start) begin
                    next_state = SCAN;
                end else begin
                    next_state = IDLE;
                end
            end

            SCAN: begin
                // Pointer iteration handled in sequential block or combinational logic
                // For this logic, we assume the pointer logic updates registers
                // Here we just transition state after 8 cycles
                if (ptr == 3'd7) begin
                    next_state = COMPUTE;
                end else begin
                    next_state = SCAN;
                end
            end

            COMPUTE: begin
                // Calculate product or set default -1
                if ($signed(first_even) == -16'sd1 || $signed(first_odd) == -16'sd1) begin
                    next_result = 16'hFFFF;
                end else begin
                    next_result = first_even * first_odd;
                end
                next_state = FINISH;
            end

            FINISH: begin
                next_done = 1'b1;
                if (!start) begin
                    next_state = IDLE;
                end else begin
                    next_state = FINISH;
                end
            end

            default: next_state = IDLE;
        endcase
    end

    // Scan Logic (Pointer and Register Update)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ptr <= 3'd0;
            first_even <= -16'sd1;
            first_odd <= -16'sd1;
        end else begin
            if (state == IDLE && start) begin
                // Reset pointers and registers on start
                ptr <= 3'd0;
                first_even <= -16'sd1;
                first_odd <= -16'sd1;
            end else if (state == SCAN) begin
                // Process current element if not already found
                if (first_even == -16'sd1 && (data_in[ptr] % 2 == 0)) begin
                    first_even <= data_in[ptr];
                end
                if (first_odd == -16'sd1 && (data_in[ptr] % 2 != 0)) begin
                    first_odd <= data_in[ptr];
                end
                
                // Increment pointer
                if (ptr < 3'd7) begin
                    ptr <= ptr + 1'b1;
                end
            end
        end
    end

endmodule

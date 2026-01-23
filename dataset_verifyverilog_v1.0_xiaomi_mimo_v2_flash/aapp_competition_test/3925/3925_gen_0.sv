module zebra_max (
    input clk,
    input rst_n,
    input start,
    input [3:0] actual_length,
    input [15:0] string_in,
    output reg [4:0] result,
    output reg done
);

    // Internal state registers
    reg [1:0] state;
    reg [4:0] i;              // 0 to 31 (2*n)
    reg [4:0] idx;            // circular index (0 to 15)
    reg [4:0] run_reg;        // current run length
    reg [4:0] max_run_reg;    // max run length
    reg prev_char;            // previous character
    reg [15:0] string_storage;
    reg [4:0] n;              // actual_length (0-16)

    // Combinational next index calculation
    reg [4:0] next_idx;
    always @(*) begin
        if (idx == n-1)
            next_idx = 5'd0;
        else
            next_idx = idx + 5'd1;
    end

    wire next_char;
    assign next_char = string_storage[next_idx];

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] NEXT = 2'd1;
    localparam [1:0] DONE = 2'd2;

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 5'd0;
            i <= 5'd0;
            idx <= 5'd0;
            run_reg <= 5'd0;
            max_run_reg <= 5'd0;
            prev_char <= 1'b0;
            string_storage <= 16'd0;
            n <= 5'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        if (actual_length == 4'd0) begin
                            result <= 5'd0;
                            done <= 1'b1;
                            state <= DONE;
                        end else begin
                            n <= actual_length;
                            string_storage <= string_in;
                            i <= 5'd0;
                            idx <= 5'd0;
                            run_reg <= 5'd1;
                            max_run_reg <= 5'd1;
                            prev_char <= string_in[0];
                            state <= NEXT;
                        end
                    end
                end

                NEXT: begin
                    // Check alternation
                    if (next_char != prev_char) begin
                        if (run_reg < n)
                            run_reg <= run_reg + 5'd1;
                        else
                            run_reg <= n;
                        if (run_reg + 5'd1 > max_run_reg)
                            max_run_reg <= run_reg + 5'd1;
                    end else begin
                        run_reg <= 5'd1;
                    end

                    // Update state
                    prev_char <= next_char;
                    idx <= next_idx;
                    i <= i + 5'd1;

                    // Finish after 2*n-1 iterations (i from 0 to 2*n-2)
                    if (i == (2*n - 5'd2))
                        state <= DONE;
                end

                DONE: begin
                    // Cap result at n
                    if (max_run_reg > n)
                        result <= n;
                    else
                        result <= max_run_reg;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule
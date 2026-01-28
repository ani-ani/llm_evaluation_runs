module LastDigitSolver(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [15:0] a [0:15],
    input wire [7:0] k_in,
    output reg [7:0] result_count,
    output reg [7:0] result_d [0:15],
    output reg done
);

    // State declarations
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] COMPUTE_GCD = 4'd1;
    localparam [3:0] GENERATE_RESULTS = 4'd2;
    localparam [3:0] FINISH = 4'd3;

    reg [3:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd32;

    // GCD computation variables
    reg [15:0] g_temp;
    reg [7:0] g_final;
    reg [7:0] current_index;
    reg [7:0] result_index;

    // GCD function using Euclidean algorithm
    function [15:0] compute_gcd;
        input [15:0] a, b;
        reg [15:0] x, y, temp;
        begin
            x = a;
            y = b;
            while (y != 16'd0) begin
                temp = y;
                y = x % y;
                x = temp;
            end
            compute_gcd = x;
        end
    endfunction

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_count <= 8'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            current_index <= 8'd0;
            result_index <= 8'd0;
            g_temp <= 16'd0;
            g_final <= 8'd0;
            // Initialize result_d array
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                result_d[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE_GCD;
                        g_temp <= k_in;
                        current_index <= 8'd0;
                    end
                end

                COMPUTE_GCD: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (current_index < n) begin
                        // Compute a[current_index] % k_in
                        reg [15:0] a_mod;
                        a_mod = a[current_index] % k_in;
                        g_temp = compute_gcd(g_temp, a_mod);
                        current_index <= current_index + 8'd1;
                    end else begin
                        g_final <= g_temp[7:0];
                        state <= GENERATE_RESULTS;
                        result_index <= 8'd0;
                        result_count <= k_in / g_final;
                    end
                end

                GENERATE_RESULTS: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (result_index < result_count) begin
                        result_d[result_index] <= result_index * g_final;
                        result_index <= result_index + 8'd1;
                    end else begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
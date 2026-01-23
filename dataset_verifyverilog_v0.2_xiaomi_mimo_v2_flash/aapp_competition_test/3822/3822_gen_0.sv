module bus_excursion(
    input clk,
    input rst_n,
    input start,
    input [15:0] l,
    input [15:0] v1,
    input [15:0] v2,
    input [3:0] n,
    output reg [31:0] result,
    output reg done
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam CALCULATE = 2'b01;
    localparam FINALIZE = 2'b10;
    localparam COMPLETE = 2'b11;

    reg [1:0] state;
    reg [5:0] count;

    // Binary search registers (Q32.16 format)
    reg [47:0] low;
    reg [47:0] high;
    reg [47:0] mid;

    // Helper wires
    wire [15:0] n_factor;
    assign n_factor = (n << 1) - 1;

    wire [47:0] l_extended;
    assign l_extended = {l, 16'b0};

    // Logic for CALCULATE state
    wire [63:0] mid_times_n;
    assign mid_times_n = mid * n_factor;

    wire [47:0] T_val;
    assign T_val = mid_times_n[47:0] - l_extended;

    wire [47:0] S_val;
    assign S_val = l_extended - mid;

    wire [79:0] T_v1;
    wire [79:0] S_v2;

    // We only need the comparison, but let's handle sizes.
    // T_val (48), v1 (16) -> 64 bits.
    // S_val (48), v2 (16) -> 64 bits.
    // Use 80 bits to be safe.
    assign T_v1 = T_val * v1;
    assign S_v2 = S_val * v2;

    // Final calculation logic (for FINALIZE state)
    // Part 1: (low / v2)
    wire [63:0] part1_num;
    assign part1_num = {low, 16'b0};
    wire [63:0] div1;
    assign div1 = part1_num / v2;

    // Part 2: ((l - low) / v1)
    wire [63:0] part2_num;
    wire [47:0] l_minus_low;
    assign l_minus_low = l_extended - low;
    assign part2_num = {l_minus_low, 16'b0};
    wire [63:0] div2;
    assign div2 = part2_num / v1;

    wire [63:0] sum_res;
    assign sum_res = div1 + div2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            result <= 0;
            count <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        low <= 0;
                        high <= {l, 16'b0};
                        count <= 0;
                        state <= CALCULATE;
                        done <= 0;
                    end
                end

                CALCULATE: begin
                    mid <= (low + high) >> 1;
                    
                    if (T_v1 > S_v2) begin
                        high <= (low + high) >> 1;
                    end else begin
                        low <= (low + high) >> 1;
                    end

                    if (count == 31) begin
                        state <= FINALIZE;
                    end else begin
                        count <= count + 1;
                    end
                end

                FINALIZE: begin
                    // Compute result from the final 'low' value (which approximates the optimal distance)
                    // result = (low / v2) + ((l - low) / v1)
                    // sum_res is Q32.32. We need to output Q16.16 (32 bits).
                    // sum_res[47:16] gives the Q16.16 representation.
                    result <= sum_res[47:16];
                    state <= COMPLETE;
                end

                COMPLETE: begin
                    done <= 1;
                    if (!start) begin
                        state <= IDLE;
                        done <= 0;
                    end
                end
            endcase
        end
    end

endmodule
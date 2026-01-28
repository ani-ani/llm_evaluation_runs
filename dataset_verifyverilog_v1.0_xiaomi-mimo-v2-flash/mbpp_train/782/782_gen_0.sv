module sum_odd_subarrays(
    input clk,
    input rst_n,
    input start,
    input signed [7:0] arr [0:7],
    input [3:0] len,
    output reg signed [15:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] DONE    = 2'd2;

    // Registers
    reg [1:0] state;
    reg [3:0] index;           // 0 to 7
    reg signed [15:0] accumulator;
    reg [7:0] cycle_count;
    
    // Local parameters
    localparam [7:0] MAX_CYCLES = 8'd50;  // Safe limit

    // Intermediate wires for arithmetic
    wire [8:0] i_plus_1;
    wire [8:0] len_minus_i;
    wire [17:0] product;
    wire [16:0] term_times_2;  // (product + 1)
    wire [16:0] term;
    wire signed [24:0] product_signed;
    wire signed [15:0] clamped_product;

    // Combinational calculations
    assign i_plus_1 = {4'd0, index} + 9'd1;
    assign len_minus_i = {4'd0, len} - {4'd0, index};
    assign product = i_plus_1 * len_minus_i;
    assign term_times_2 = product + 17'd1;
    assign term = term_times_2[16:1];  // Right shift by 1 (divide by 2)
    
    // Signed multiplication with clamping
    assign product_signed = $signed({{7{term[16]}}, term[16:0]}) * $signed(arr[index]);
    assign clamped_product = (product_signed > 32767) ? 16'sd32767 :
                            (product_signed < -32768) ? 16'sd-32768 :
                            product_signed[15:0];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            result <= 16'sd0;
            done <= 1'b0;
            accumulator <= 16'sd0;
            index <= 4'd0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    accumulator <= 16'sd0;
                    index <= 4'd0;
                    cycle_count <= 8'd0;
                    if (start && len >= 4'd1 && len <= 4'd8) begin
                        state <= COMPUTE;
                    end else if (start) begin
                        // Invalid length, go to done immediately
                        state <= DONE;
                    end
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (index < len) begin
                        // Accumulate term * arr[i]
                        accumulator <= accumulator + clamped_product;
                        index <= index + 4'd1;
                    end
                    
                    // Exit conditions
                    if (index >= len || cycle_count >= MAX_CYCLES) begin
                        result <= accumulator;
                        state <= DONE;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
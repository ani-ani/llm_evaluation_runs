module multiply_num #(
    parameter N = 5,
    parameter WIDTH = 32
) (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [WIDTH-1:0] data_in,
    input wire [2:0] index,
    input wire data_valid,
    output reg [WIDTH-1:0] result,
    output reg done,
    output reg [2:0] state
);

    // States
    localparam IDLE = 3'b000;
    localparam LOAD = 3'b001;
    localparam COMPUTE = 3'b010;
    localparam DIVIDE = 3'b011;
    localparam DONE = 3'b100;

    // Internal Registers
    reg [WIDTH-1:0] storage [0:N-1];
    reg [N-1:0] valid_mask;
    reg signed [63:0] product_acc;
    reg signed [63:0] dividend_reg;
    reg signed [63:0] remainder_reg;
    reg signed [63:0] quotient_reg;
    reg [5:0] counter;
    reg [$clog2(N):0] mult_count;
    reg sign_bit;

    // Division Helper Wires (Comb logic)
    wire signed [63:0] calc_rem;
    wire signed [63:0] calc_div;
    wire signed [63:0] next_rem_val;
    wire signed [63:0] next_quot_val;
    wire signed [63:0] div_val_wire;

    assign div_val_wire = 64'sd5;
    assign calc_rem = {remainder_reg[62:0], dividend_reg[63]};
    assign calc_div = {dividend_reg[62:0], 1'b0};
    assign next_rem_val = (calc_rem >= div_val_wire) ? (calc_rem - div_val_wire) : calc_rem;
    assign next_quot_val = (quotient_reg << 1) | ((calc_rem >= div_val_wire) ? 1'b1 : 1'b0);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 0;
            done <= 1'b0;
            valid_mask <= 0;
            product_acc <= 0;
            counter <= 0;
            mult_count <= 0;
            remainder_reg <= 0;
            quotient_reg <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    // Check if all data loaded
                    if (valid_mask != {N{1'b1}}) begin
                        // Wait for data if not full
                        if (data_valid && index < N) begin
                            storage[index] <= data_in;
                            valid_mask[index] <= 1'b1;
                            state <= LOAD;
                        end
                    end else begin
                        // Full, wait for start signal
                        if (start) begin
                            state <= COMPUTE;
                            mult_count <= 0;
                            product_acc <= 64'sd1 << 32; // Initialize 1.0 in Q32.32
                        end
                    end
                end

                LOAD: begin
                    if (data_valid && index < N) begin
                        storage[index] <= data_in;
                        valid_mask[index] <= 1'b1;
                    end
                    if (valid_mask == {N{1'b1}}) begin
                        state <= IDLE;
                    end
                end

                COMPUTE: begin
                    if (mult_count < N) begin
                        // Multiply and shift right 16 to maintain Q32.32
                        // product_acc is Q32.32, storage is Q16.16
                        product_acc <= (product_acc * storage[mult_count]) >>> 16;
                        mult_count <= mult_count + 1;
                    end else begin
                        state <= DIVIDE;
                        counter <= 0;
                    end
                end

                DIVIDE: begin
                    if (counter == 0) begin
                        // Initialize division (Magnitude calculation)
                        if (product_acc[63]) begin
                            sign_bit <= 1'b1;
                            dividend_reg <= -product_acc;
                        end else begin
                            sign_bit <= 1'b0;
                            dividend_reg <= product_acc;
                        end
                        remainder_reg <= 0;
                        quotient_reg <= 0;
                        counter <= 1;
                    end else if (counter <= 64) begin
                        // Iterative restoring division step
                        // Uses comb logic wires to calculate next values
                        remainder_reg <= next_rem_val;
                        quotient_reg <= next_quot_val;
                        dividend_reg <= calc_div;
                        counter <= counter + 1;
                    end else begin
                        // Finalize Result
                        if (sign_bit) begin
                            quotient_reg <= -quotient_reg;
                        end
                        // quotient_reg is Q32.32, result needs Q16.16 -> shift right 16
                        result <= quotient_reg >>> 16;
                        state <= DONE;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                    valid_mask <= 0; // Reset for next computation
                end
            endcase
        end
    end

endmodule
module round_and_sum (
    input clk,
    input rst_n,
    input start,
    input [2:0] list_length,
    input [31:0] list_data [0:7],
    output reg [31:0] result,
    output reg done
);

    // States
    localparam IDLE = 3'b000;
    localparam LOAD = 3'b001;
    localparam ROUNDING = 3'b010;
    localparam SUMMING = 3'b011;
    localparam MULTIPLYING = 3'b100;
    localparam DONE = 3'b101;

    reg [2:0] state;
    reg [2:0] index;
    reg [31:0] data_reg [0:7]; // Stored list data
    reg [2:0] len_reg; // Stored list length
    reg [31:0] sum_reg; // Stores sum of rounded integers (32-bit sufficient for 8*2^16)
    reg [31:0] temp_rounded; // Stores current rounded value
    reg [47:0] mult_temp; // 48-bit for multiplication to avoid overflow
    
    // Constant 0.5 in Q16.16 format
    localparam [31:0] HALF = 32'h00008000;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 32'b0;
            index <= 3'b0;
            sum_reg <= 32'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= LOAD;
                    end
                end

                LOAD: begin
                    // Load inputs into local storage
                    len_reg <= list_length;
                    data_reg[0] <= list_data[0];
                    data_reg[1] <= list_data[1];
                    data_reg[2] <= list_data[2];
                    data_reg[3] <= list_data[3];
                    data_reg[4] <= list_data[4];
                    data_reg[5] <= list_data[5];
                    data_reg[6] <= list_data[6];
                    data_reg[7] <= list_data[7];
                    index <= 3'b0;
                    sum_reg <= 32'b0;
                    state <= ROUNDING;
                end

                ROUNDING: begin
                    // Check if index < len_reg (handle len_reg = 0 case)
                    if (index < len_reg) begin
                        // Round: (number + 0.5) >> 16
                        temp_rounded <= (data_reg[index] + HALF) >> 16;
                        state <= SUMMING;
                    end else begin
                        state <= MULTIPLYING;
                    end
                end

                SUMMING: begin
                    sum_reg <= sum_reg + temp_rounded;
                    index <= index + 1'b1;
                    state <= ROUNDING;
                end

                MULTIPLYING: begin
                    // Multiply sum by list_length
                    // Use 48-bit to prevent overflow (max sum ~ 524280, * 8 = ~4.2e6, fits in 22 bits)
                    mult_temp <= sum_reg * len_reg;
                    state <= DONE;
                end

                DONE: begin
                    // Convert back to Q16.16 by shifting left 16
                    result <= mult_temp[31:0] << 16; // Ensure result fits in 32 bits
                    done <= 1'b1;
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule
